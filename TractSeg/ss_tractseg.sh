#!/bin/bash
#SBATCH --time=1-00:00:00
#SBATCH --mem=40GB
#SBATCH --cpus-per-task=8
#SBATCH -J tractseg

set -eu
# Get arguments from submit_job_array.sh
base=$2
args=($@)
subjs=(${args[@]:2})
sub=${subjs[${SLURM_ARRAY_TASK_ID}]}
echo $sub

# Define scratch, derivatives, and container paths for convenience
scratch=/PATH/TO/SCRATCH/tractseg
mkdir -p $scratch
qsiprep_dir=$base/derivatives/qsiprep
tractseg_dir=$base/derivatives/TractSeg_NEW
tractseg="singularity exec -e -B $base,$scratch /PATH/TO/tractseg_23.img"
mrtrix3t="singularity exec -e -B $base,$scratch /PATH/TO/mrtrix3t.img"
mrtrix="singularity exec -e -B $base,$scratch /PATH/TO/mrtrix_3.0.3.img"
fsl="singularity exec -e -B $base,$scratch /PATH/TO/fsl.img"

# Make sure QSIPrep has run for subject
test_folder=${qsiprep_dir}/$sub/dwi/
if [[ ! -d $test_folder ]] ; then
    echo 'No DWI, aborting.'
    exit
fi


#################################################

# Begin Running
mkdir -p $tractseg_dir/$sub/dwi

# Test File Naming Convention
test_str=${tractseg_dir}/$sub/dwi/*dwi.nii.gz
if [[ $(basename -- $test_str) = *"run-1"* ]]; then
  run=run-1_
else
  run=""
fi

#################################################

echo 'REORIENTING FILES'
$fsl fslreorient2std ${qsiprep_dir}/$sub/dwi/*T1*dwi.nii.gz ${tractseg_dir}/$sub/dwi/${sub}_${run}space-reorient_desc-preproc_dwi.nii.gz
$fsl fslreorient2std ${qsiprep_dir}/$sub/dwi/*T1*mask.nii.gz ${tractseg_dir}/$sub/dwi/${sub}_${run}space-reorient_desc-brain_mask.nii.gz
$fsl fslreorient2std ${qsiprep_dir}/$sub/anat/${sub}_desc-preproc_T1w.nii.gz ${tractseg_dir}/$sub/dwi/${sub}_space-reorient_desc-preproc_T1w.nii.gz

echo "CORRECTING GRADIENTS"
$mrtrix dwigradcheck ${tractseg_dir}/$sub/dwi/${sub}_${run}space-reorient_desc-preproc_dwi.nii.gz \
	-mask ${tractseg_dir}/$sub/dwi/${sub}_${run}space-reorient_desc-brain_mask.nii.gz -grad ${qsiprep_dir}/$sub/dwi/${sub}*.b \
	-export_grad_mrtrix ${tractseg_dir}/$sub/dwi/${sub}_${run}space-reorient_desc-preproc_dwi.b -scratch $scratch -force

echo "CREATING .MIF FILE"
$mrtrix mrconvert ${tractseg_dir}/$sub/dwi/*reorient*dwi.nii.gz \
${tractseg_dir}/$sub/dwi/${sub}_${run}space-reorient_desc-preproc_dwi.mif -grad ${tractseg_dir}/$sub/dwi/*reorient*.b -force

echo "FITTING TENSOR AND CALCULATING FA"
$mrtrix dwi2tensor ${tractseg_dir}/$sub/dwi/*.mif ${tractseg_dir}/$sub/dwi/${sub}_${run}space-reorient_tensor.nii.gz \
	-mask ${tractseg_dir}/$sub/dwi/*reorient*mask.nii.gz -force #-dkt ${tractseg_dir}/$sub/dwi/${sub}_${run}space-reorient_tensor-DKT.nii.gz
$mrtrix tensor2metric ${tractseg_dir}/$sub/dwi/*tensor.nii.gz -mask ${tractseg_dir}/$sub/dwi/*reorient*mask.nii.gz \
	-fa ${tractseg_dir}/$sub/dwi/${sub}_${run}space-reorient_desc-preproc_FA.nii.gz \
	-vector ${tractseg_dir}/$sub/dwi/${sub}_${run}space-reorient_desc-preproc_vector.nii.gz \
	-force
# UNCOMMENT THIS TO CALCULATE DIFFUSION KURTOSIS TENSOR
#$mrtrix tensor2metric ${tractseg_dir}/$sub/dwi/*tensor-DKT.nii.gz -mask ${tractseg_dir}/$sub/dwi/*reorient*mask.nii.gz \
#	-fa ${tractseg_dir}/$sub/dwi/${sub}_${run}space-reorient_desc-preproc_FA-DKT.nii.gz \
#	-vector ${tractseg_dir}/$sub/dwi/${sub}_${run}space-reorient_desc-preproc_vector-DKT.nii.gz \
#	-force
#################################################

echo 'CREATING CSD PEAKS'
echo 'Step1: Estimate response functions of WM, GM, CSF (USING dhollander ALGORITHM)'
$mrtrix dwi2response dhollander ${tractseg_dir}/$sub/dwi/*reorient*dwi.mif \
 ${tractseg_dir}/$sub/dwi/response_wm.txt ${tractseg_dir}/$sub/dwi/response_gm.txt ${tractseg_dir}/$sub/dwi/response_csf.txt \
-mask ${tractseg_dir}/$sub/dwi/*reorient*mask.nii.gz -scratch $scratch -force

if [ "$1" = "single" ]; then
	# USE SINGLE SHELL 3TISSUE ALGORITHM FOR SINGLE SHELL
	echo 'Step2: Estimate FODs with Single Shell 3 Tissue Algorithm'
	$mrtrix3t ss3t_csd_beta1 ${tractseg_dir}/$sub/dwi/*reorient*dwi.mif \
	${tractseg_dir}/$sub/dwi/response_wm.txt ${tractseg_dir}/$sub/dwi/wmfod.nii.gz \
	${tractseg_dir}/$sub/dwi/response_gm.txt ${tractseg_dir}/$sub/dwi/gm.nii.gz \
	${tractseg_dir}/$sub/dwi/response_csf.txt ${tractseg_dir}/$sub/dwi/csf.nii.gz \
	-mask ${tractseg_dir}/$sub/dwi/*reorient*mask.nii.gz -force
else
	# USE MULTISHELL MULTI TISSUE ALGORITHM FOR MULTISHELL
	echo 'Step2: Estimate FODs with Multi Shell Multi Tissue Algorithm'
	$mrtrix dwi2fod msmt_csd ${tractseg_dir}/$sub/dwi/*reorient*dwi.mif \
 	${tractseg_dir}/$sub/dwi/response_wm.txt ${tractseg_dir}/$sub/dwi/wmfod.nii.gz \
	${tractseg_dir}/$sub/dwi/response_gm.txt ${tractseg_dir}/$sub/dwi/gm.nii.gz \
	${tractseg_dir}/$sub/dwi/response_csf.txt ${tractseg_dir}/$sub/dwi/csf.nii.gz \
	-mask ${tractseg_dir}/$sub/dwi/*reorient*mask.nii.gz -force
fi

echo 'Step3: Normalize FODs'
$mrtrix mtnormalise ${tractseg_dir}/$sub/dwi/wmfod.nii.gz ${tractseg_dir}/$sub/dwi/wmfod_norm.nii.gz \
${tractseg_dir}/$sub/dwi/gm.nii.gz ${tractseg_dir}/$sub/dwi/gm_norm.nii.gz \
${tractseg_dir}/$sub/dwi/csf.nii.gz ${tractseg_dir}/$sub/dwi/csf_norm.nii.gz \
-mask ${tractseg_dir}/$sub/dwi/*reorient*mask.nii.gz -force

echo 'Step4: Generate Peaks'
$mrtrix sh2peaks ${tractseg_dir}/$sub/dwi/wmfod_norm.nii.gz ${tractseg_dir}/$sub/dwi/peaks.nii.gz -quiet \
	-mask ${tractseg_dir}/$sub/dwi/*reorient*mask.nii.gz -force

echo 'RUNNING TRACTSEG'
$tractseg TractSeg -i ${tractseg_dir}/$sub/dwi/peaks.nii.gz -o ${tractseg_dir}/$sub
$tractseg TractSeg -i ${tractseg_dir}/$sub/dwi/peaks.nii.gz -o ${tractseg_dir}/$sub --output_type endings_segmentation
$tractseg TractSeg -i ${tractseg_dir}/$sub/dwi/peaks.nii.gz -o ${tractseg_dir}/$sub --output_type TOM 
$tractseg Tracking -i ${tractseg_dir}/$sub/dwi/peaks.nii.gz -o ${tractseg_dir}/$sub  --tracking_format trk --nr_fibers 5000
$tractseg Tractometry -i ${tractseg_dir}/$sub/TOM_trackings/ -o  ${tractseg_dir}/$sub/FA_tractometry.csv \
-e  ${tractseg_dir}/$sub/endings_segmentations/ -s ${tractseg_dir}/$sub/dwi/*reorient*FA.nii.gz --tracking_format trk

cp ${tractseg_dir}/$sub/dwi/*reorient*brain_mask.nii.gz ${tractseg_dir}/$sub/nodif_brain_mask.nii.gz
cp $base/code/TractSeg/subjects.txt $tractseg_dir/subjects.txt
