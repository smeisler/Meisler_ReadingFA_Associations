#!/bin/bash
#SBATCH --time=3-00:00:00
#SBATCH --mem=20GB
#SBATCH --cpus-per-task=8
#SBATCH -J qsiprep
set -eu

args=($@)
subjs=(${args[@]:1})
bids_dir=$1
# SET THIS TO BE THE PATH TO YOUR QSIPREP SINGULARITY IMAGE
IMG=

# index slurm array to grab subject
subject=${subjs[${SLURM_ARRAY_TASK_ID}]}

# assign working directory
# SET THIS TO BE THE PATH TO YOUR SCRATCH DIRECTORY
scratch=
# assign output directory
output_dir=${bids_dir}/derivatives

mkdir -p ${scratch}
# mkdir -p "${base}/derivatives"
mkdir -p ${output_dir}

cmd="singularity run -B ${scratch}:/workdir -B ${bids_dir}:/mnt:ro -B ${output_dir}:/output -B ${bids_dir}/code/qsiprep/license.txt:/license.txt $IMG --participant_label ${subject:4} -w /workdir --fs-license-file /license.txt --mem_mb 19000 --unringing_method mrdegibbs --skip-bids-validation --output_resolution 1.2 /mnt /output participant"
#--use-syn-sdc --force-syn
echo Submitted job for: ${subject}
echo $'Command :\n'${cmd}

${cmd}
