# Step 1: Run QSIPrep to Preprocess DWI
- Download the code/QSIPrep folder to your BIDS code folder. In it, add your FreeSurfer license as license.txt (case-sensitive).
- In the `submit_job_array.sh` script, udpate the variable bids in the beginning of the script to direct to your BIDS directory. Additionally, in the last line of the script, you can update the parameter after % to limit how many jobs can be active at a time. We set this to 100 as a default, but you can alter this or delete it to not set a limit.
- In the `ss_qsiprep.sh` script, change the SBATCH header to match your desired parameters (e.g. memory usage, time-to-wall, etc). Then update the variable IMG to the path of your QSIPrep singularity image. Set the variable scratch to where you want intermediate files to be stored during the QSIPrep workflow. Review the command at the bottom of the script to make sure you understand how QSIPrep is being run and change any parameters you would like.
- Make sure Singularity is loaded in your environment.
- In terminal, navigate to the QSIPrep code folder, and run `./submit_job_array.sh` to begin QSIPrep.
