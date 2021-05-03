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
base=

if [[ $# -eq 0 ]]; then
    # first go to data directory, grab all subjects,
    # and assign to an array
    pushd $base
    subjs=($(ls sub* -d))
    popd
fi


# take the length of the array
# this will be useful for indexing later
len=$(expr ${#subjs[@]} - 1) # len - 1

echo Spawning ${#subjs[@]} sub-jobs.

single_multi='multi' # Single or multi-shell data
flip_x='yes' # Need to flip peaks over x-axis
sbatch --array=0-$len%100 ss_tractseg.sh $single_multi $flip_x $base ${subjs[@]}
