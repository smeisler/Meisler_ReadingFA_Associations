#!/bin/bash
#SBATCH --time=2-00:00:00
#SBATCH --mem=40GB
#SBATCH --cpus-per-task=4
#SBATCH -J tractseg

# UPDATE THESE PATHS TO LEAD TO YOUR SINGULARITY IMAGES
tractseg=/PATH/TO/tractseg.simg
mrtrix_fsl=/PATH/TO/mrtrix_fsl.simg
mrtrix3t=/PATH/TO/mrtrix3t.simg

set -eu
# Get arguments from submit_job_array.sh
base=$3
args=($@)
subjs=(${args[@]:3})
sub=${subjs[${SLURM_ARRAY_TASK_ID}]}
echo $sub
# Define paths for convenience
qsiprep_dir=$base/derivatives/qsiprep
qsirecon_dir=$base/derivatives/qsirecon
tractseg_dir=$base/derivatives/TractSeg
MNI_template=$base/code/TractSeg/MNI_FA_template.nii.gz

# Make sure QSIPrep has run for subject
test_folder=${qsiprep_dir}/$sub/dwi/
if [[ ! -d $test_folder ]] ; then
    echo 'No DWI, aborting.'
    exit
fi


#################################################

# Begin Running
#mkdir $tractseg_dir
#mkdir $tractseg_dir/$sub
mkdir -p $tractseg_dir/$sub/dwi

# Copy Important Files to TractSeg Directory
cp ${qsiprep_dir}/$sub/dwi/${sub}*.bval ${tractseg_dir}/$sub/dwi/
cp ${qsiprep_dir}/$sub/dwi/${sub}*.bvec ${tractseg_dir}/$sub/dwi/
cp ${qsiprep_dir}/$sub/dwi/${sub}*dwi.nii.gz ${tractseg_dir}/$sub/dwi/
cp ${qsiprep_dir}/$sub/dwi/${sub}*mask.nii.gz ${tractseg_dir}/$sub/dwi/

# Test File Naming Convention
test_str=${tractseg_dir}/$sub/dwi/*dwi.nii.gz
if [[ $(basename -- $test_str) = *"run-1"* ]]; then
  run=run-1_
else
  run=""
fi

cp ${qsiprep_dir}/$sub/dwi/${sub}*.bval ${tractseg_dir}/$sub/dwi/${sub}_${run}space-MNI_desc-preproc_dwi.bval
#################################################

echo 'REGISTERING FILES TO MNI'
singularity exec -e -B $base $tractseg calc_FA -i ${tractseg_dir}/$sub/dwi/*T1*dwi.nii.gz \
-o ${tractseg_dir}/$sub/dwi/${sub}_${run}space-T1w_desc-preproc_FA.nii.gz \
--bvals ${tractseg_dir}/$sub/dwi/*T1*bval --bvecs ${tractseg_dir}/$sub/dwi/*T1*.bvec \
--brain_mask ${tractseg_dir}/$sub/dwi/*T1*mask.nii.gz

singularity exec -e -B $base $mrtrix_fsl flirt -ref $MNI_template -in ${tractseg_dir}/$sub/dwi/*T1*FA.nii.gz \
-out ${tractseg_dir}/$sub/dwi/${sub}_${run}space-MNI_desc-preproc_FA.nii.gz -omat ${tractseg_dir}/$sub/dwi/FA_2_MNI.mat \
-dof 6 -cost mutualinfo -searchcost mutualinfo

singularity exec -e -B $base $mrtrix_fsl flirt -ref $MNI_template -in ${tractseg_dir}/$sub/dwi/*T1*dwi.nii.gz \
-out ${tractseg_dir}/$sub/dwi/${sub}_${run}space-MNI_desc-preproc_dwi.nii.gz \
-applyxfm -init ${tractseg_dir}/$sub/dwi/FA_2_MNI.mat -dof 6

singularity exec -e -B $base $mrtrix_fsl flirt -ref $MNI_template -in ${tractseg_dir}/$sub/dwi/*T1*mask.nii.gz \
-out ${tractseg_dir}/$sub/dwi/${sub}_${run}space-MNI_desc-brain_mask.nii.gz \
-applyxfm -init ${tractseg_dir}/$sub/dwi/FA_2_MNI.mat -dof 6

singularity exec -e -B $base $tractseg rotate_bvecs -i ${tractseg_dir}/$sub/dwi/*T1*.bvec -t \
${tractseg_dir}/$sub/dwi/FA_2_MNI.mat -o ${tractseg_dir}/$sub/dwi/${sub}_${run}space-MNI_desc-preproc_dwi.bvec

singularity exec -e -B $base $mrtrix_fsl mrconvert ${tractseg_dir}/$sub/dwi/*MNI*dwi.nii.gz \
${tractseg_dir}/$sub/dwi/${sub}_${run}space-MNI_desc-preproc_dwi.mif -fslgrad ${tractseg_dir}/$sub/dwi/*MNI*.bvec ${tractseg_dir}/$sub/dwi/*MNI*.bval
#################################################

echo 'CREATING CSD PEAKS'
echo 'Step1: Estimate response functions of WM, GM, CSF (USING dhollander ALGORITHM)'
singularity exec -e -B $base $mrtrix_fsl dwi2response dhollander ${tractseg_dir}/$sub/dwi/*MNI*dwi.mif \
 ${tractseg_dir}/$sub/dwi/response_wm.txt ${tractseg_dir}/$sub/dwi/response_gm.txt ${tractseg_dir}/$sub/dwi/response_csf.txt \
-mask ${tractseg_dir}/$sub/dwi/*MNI*mask.nii.gz -quiet

if [ "$1" = "single" ]; then
	# USE SINGLE SHELL 3TISSUE ALGORITHM FOR SINGLE SHELL
	echo 'Step2: Estimate FODs with Single Shell 3 Tissue Algorithm'
	singularity exec -e -B $base $mrtrix3t ss3t_csd_beta1 ${tractseg_dir}/$sub/dwi/*MNI*dwi.mif \
	${tractseg_dir}/$sub/dwi/response_wm.txt ${tractseg_dir}/$sub/dwi/wmfod.nii.gz \
	${tractseg_dir}/$sub/dwi/response_gm.txt ${tractseg_dir}/$sub/dwi/gm.nii.gz \
	${tractseg_dir}/$sub/dwi/response_csf.txt ${tractseg_dir}/$sub/dwi/csf.nii.gz \
	-mask ${tractseg_dir}/$sub/dwi/*MNI*mask.nii.gz
else
	# USE MULTISHELL MULTI TISSUE ALGORITHM FOR MULTISHELL
	echo 'Step2: Estimate FODs with Multi Shell Multi Tissue Algorithm'
	singularity exec -e -B $base $mrtrix_fsl dwi2fod msmt_csd ${tractseg_dir}/$sub/dwi/*MNI*dwi.mif \
 	${tractseg_dir}/$sub/dwi/response_wm.txt ${tractseg_dir}/$sub/dwi/wmfod.nii.gz \
	${tractseg_dir}/$sub/dwi/response_gm.txt ${tractseg_dir}/$sub/dwi/gm.nii.gz \
	${tractseg_dir}/$sub/dwi/response_csf.txt ${tractseg_dir}/$sub/dwi/csf.nii.gz \
	-mask ${tractseg_dir}/$sub/dwi/*MNI*mask.nii.gz
fi

echo 'Step3: Normalize FODs'
singularity exec -e -B $base $mrtrix_fsl mtnormalise ${tractseg_dir}/$sub/dwi/wmfod.nii.gz ${tractseg_dir}/$sub/dwi/wmfod_norm.nii.gz \
${tractseg_dir}/$sub/dwi/gm.nii.gz ${tractseg_dir}/$sub/dwi/gm_norm.nii.gz \
${tractseg_dir}/$sub/dwi/csf.nii.gz ${tractseg_dir}/$sub/dwi/csf_norm.nii.gz \
-mask ${tractseg_dir}/$sub/dwi/*MNI*mask.nii.gz

echo 'Step4: Generate Peaks'
singularity exec -e -B $base $mrtrix_fsl sh2peaks ${tractseg_dir}/$sub/dwi/wmfod_norm.nii.gz ${tractseg_dir}/$sub/dwi/peaks_MNI.nii.gz -quiet

if [ "$2" = "yes" ]; then
	echo 'Step5: Flip Peaks Along X-Axis'
	singularity exec -e -B $base $tractseg flip_peaks -i ${tractseg_dir}/$sub/dwi/peaks_MNI.nii.gz \
	 -o ${tractseg_dir}/$sub/dwi/peaks_MNI.nii.gz -a x
fi

echo 'RUNNING TRACTSEG'
singularity exec -e -B $base $tractseg TractSeg -i ${tractseg_dir}/$sub/dwi/peaks_MNI.nii.gz -o ${tractseg_dir}/$sub
singularity exec -e -B $base $tractseg TractSeg -i ${tractseg_dir}/$sub/dwi/peaks_MNI.nii.gz -o ${tractseg_dir}/$sub --output_type endings_segmentation
singularity exec -e -B $base $tractseg TractSeg -i ${tractseg_dir}/$sub/dwi/peaks_MNI.nii.gz -o ${tractseg_dir}/$sub --output_type TOM 
singularity exec -e -B $base $tractseg Tracking -i ${tractseg_dir}/$sub/dwi/peaks_MNI.nii.gz -o ${tractseg_dir}/$sub  --tracking_format trk --nr_fibers 5000
singularity exec -e -B $base $tractseg Tractometry -i ${tractseg_dir}/$sub/TOM_trackings/ -o  ${tractseg_dir}/$sub/FA_tractometry.csv \
-e  ${tractseg_dir}/$sub/endings_segmentations/ -s ${tractseg_dir}/$sub/dwi/*MNI*FA.nii.gz --tracking_format trk

cp ${tractseg_dir}/$sub/dwi/*MNI*mask.nii.gz ${tractseg_dir}/$sub/nodif_brain_mask.nii.gz
cp $base/code/TractSeg/subjects.txt $tractseg_dir/subjects.txt
