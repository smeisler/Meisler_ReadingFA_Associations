## Step 2: Run TractSeg segmentation
- Download the `code/TractSeg` folder to your BIDS code folder.
- In the `submit_job_array.sh` script, udpate the variable `bids` in the beginning of the script to direct to your BIDS directory. Additionally, in the last line of the script, you can update the parameter after `%` to limit how many jobs can be active at a time. We set this to 100 as a default, but you can alter this or delete it to not set a limit.
- If using your own data, change the `single_multi` (either 'single' or 'multi') and `flip_x` variables ('yes' or 'no') to match your data. That is, single shell data only has one non-0 b-value, and sometimes, the x-gradient needs to be flipped to correct its orientation. The `flip_x` may be hard to know _apriori_, but typically Siemens data need it flipped. If unsure, leave it as 'yes', and if tracts do not look right, try changing it.
   - In single shell data, we instead use MrTrix3tissue to estimate the three tissue response functions.
- In the `ss_tractseg.sh` script, update the SBATCH header as needed to accomodate your memory usage needs, and update the first few variables to the paths to your singularity containers.
- Make sure Singularity is loaded in your environment.
- In terminal, navigate to the TractSeg code folder, and run `./submit_job_array.sh` to begin TractSeg.
