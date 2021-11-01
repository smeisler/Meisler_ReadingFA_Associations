#!/bin/bash

# Submit subjects to be run through TractSeg. Each subject
# will be run as a separate job, but all jobs will share the
# same JOBID, only will differentiate by their array number.
# Example output file: slurm-<JOBID>_<ARRAY>.out

# Usages:

# - run all subjects in project base

# bash submit_job_array.sh


subjs=$@

# SET THIS TO BE THE PATH TO YOUR BIDS DIRECTORY
bids=
single_multi='multi' # "single" or "multi"-shell data
flip_x='no' # Need to flip peaks over x-axis

if [[ $# -eq 0 ]]; then
    # first go to data directory, grab all subjects,
    # and assign to an array
    pushd $bids
    subjs=($(ls sub* -d))
    popd
fi


# take the length of the array
# this will be useful for indexing later
len=$(expr ${#subjs[@]} - 1) # len - 1

echo Spawning ${#subjs[@]} sub-jobs.


sbatch --array=0-$len%100 $bids/code/TractSeg/ss_tractseg.sh $single_multi $flip_x $bids ${subjs[@]}
