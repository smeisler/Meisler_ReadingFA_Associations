# Locate subject folders
# UPDATE THIS TO BE THE PATH TO YOUR BIDS FOLDER
bids=

for file in $bids/sub*/fmap/*; do
# Seperate file name based on _ delimeter
IFS='_' read -ra ADDR <<< "$file"
# Transpose the file name to follow BIDS
#sub-<label>[_ses-<label>][_acq-<label>][_ce-<label>]_dir-<label>[_run-<index>]_epi.nii[.gz]
#sub-<label>[_ses-<label>][_acq-<label>][_ce-<label>]_dir-<label>[_run-<index>]_epi.json
# NOTE THESE INDICES ASSUME "_" IS ONLY IN THE FILE NAME AND NOT ANYWHERE IN THE PATH TO GET TO THE FILES
if [ ${ADDR[1]} == dir-AP ]; then mv $file ${ADDR[0]}_${ADDR[2]}_${ADDR[1]}_${ADDR[3]}; fi
if [ ${ADDR[1]} == dir-PA ]; then mv $file ${ADDR[0]}_${ADDR[2]}_${ADDR[1]}_${ADDR[3]}; fi
done

