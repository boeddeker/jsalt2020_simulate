#!/bin/bash

# Set bash to 'debug' mode, it will exit on :
# -e 'error', -u 'undefined variable', -o ... 'error in pipeline', -x 'print commands',
set -e
set -u
set -o pipefail

# Programs
# Takuya's set-up
PYTHON=/usr/bin/python3.8
KALDI=/mnt/lustre/share/kaldi-master

# Environment
export PATH=${KALDI}/egs/wsj/s5/utils:${PATH}
. ./configs/cmd.sh

# Scripts
deflac=./tools/deflac.py
gen_filelist=./tools/gen_filelist.py
segment=./tools/tight_segment.py

# Hyper-parameters
nj=32       # number of splits for parallel processing

# Directories
# Takuya's set-up
srcdir=/mnt/f/DB/LibriSpeech/train  # Has to contain train-clean100 and train-clean-360 from which FLAC files are retrieved. 
dstdir=/mnt/f/Work/JelinekWorkshop2020/data/train
splitdir=$dstdir/filelist/split${nj}
mkdir -p ${splitdir}/log

# Convert FLAC files to WAV.
$PYTHON $deflac --srcdir $srcdir/train-clean-100 $srcdir/train-clean-360 --dstdir $dstdir/wav

# List the original wav files.
$PYTHON $gen_filelist --srcdir $dstdir/wav/train-clean-100 $dstdir/wav/train-clean-360 --outlist $dstdir/filelist/train.list

# Split trainlist for parallel processing
split_scp.pl ${dstdir}/filelist/train.list $(for j in $(seq ${nj}); do echo ${splitdir}/train.${j}.list; done)

# Remove silence regions from the training utterances. This allows us to accurately control the overlap ratio distribution duing training.
${gen_cmd} JOB=1:${nj} ${splitdir}/log/tight_segment.JOB.log \
    $PYTHON $segment --inputlist ${splitdir}/train.JOB.list --outputdir ${dstdir}/wav_newseg
# $PYTHON $segment --inputlist $dstdir/filelist/train.list --outputdir $dstdir/wav_newseg
