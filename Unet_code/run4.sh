#!/bin/bash

#Terminate program if anything throws non-zero exit code
set -e

# installation steps for Miniconda
export HOME=$PWD
export PATH
sh Miniconda3-latest-Linux-x86_64.sh -b -p $PWD/miniconda3
export PATH=$PWD/miniconda3/bin:$PATH

########################################
# Environment Creation
########################################
source activate base
conda env create -f environment.yml -n UNET 
conda activate UNET


wandb login `cat wandb_api_key.txt`

########################################
# Preprocessing Pipeline
########################################

#Multi coil
echo "Copying multicoil from staging..."
time cp /staging/jhiemstra/multicoil_train.tar.gz ./
echo "Multicoil done copying"

mkdir multicoil
echo "Beginning untar"
time tar -xf multicoil_train.tar.gz -C multicoil --strip-components 1
echo "Done untar"

echo "Removing multicoil tarball"
time rm multicoil_train.tar.gz
echo "Done removing multicoil tarball"

echo "Multi coil im conversion and data partitioning"
python3 kspace_to_im.py  -f "multicoil" -m -d
python3 data_partition.py -s multicoil -t "data" -a

########################################
# Training
########################################


git clone https://github.com/ccraig3/ece697-mri-denoising.git
mv ece697-mri-denoising/* ./
rm -rf ece697-mri-denoising


python3 train_unet.py --train_imgs 'data/trainA' --val_imgs 'data/valA' --test_imgs 'data/testA' --train_bias 'fields_5k_poly_train.pkl' --val_bias 'fields_5k_poly_val.pkl' --test_bias 'fields_5k_poly_test.pkl' --ckpt_save_path 'checkpoints' --proj_name 'UNet-L1+L2-cmd-line' --run_name '50 epochs --- wf=8, bicubic' --max_epochs 50 --batch_size 24 --wf 8 --precision 32 --num_gpus 2

tar -czf checkpoints_wf8_50_epochs.tar.gz checkpoints

echo "DONE"
