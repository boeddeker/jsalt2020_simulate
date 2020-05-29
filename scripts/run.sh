#!/bin/bash

# Set bash to 'debug' mode, it will exit on :
# -e 'error', -u 'undefined variable', -o ... 'error in pipeline', -x 'print commands',
set -e
set -u
set -o pipefail

# Programs
# Takuya's set-up
PYTHON=/usr/bin/python3.8
# a subset of Kaldi utils
KALDI_UTILS=./tools/kaldi_utils

# Environment
export PATH=${KALDI_UTILS}:${PATH}
. ./configs/cmd.sh

# Scripts
splitjson=./tools/splitjson.py
mergejson=./tools/mergejsons.py
gen_filelist=./tools/gen_filelist.py
list2json=./tools/list2json_librispeech.py
mixspec=./tools/gen_mixspec_2spkr.py
mixer=./tools/mixaudio.py

# Directories
# Takuya's set-up
srcdir=/mnt/f/Work/JelinekWorkshop2020/data/train/wav_newseg  # Generated by preprocess.sh.
tgtroot=/mnt/f/Work/JelinekWorkshop2020/data/LibriCSS-train


# Hyper-parameters
nj=32       # number of splits for parallel processing
ncopies=1
single_spkr=0.08
rndseed=1000
cfgfile=./configs/2mix_reverb_stanoise.json

# List the source files. 
trainlist=$tgtroot/train.list
$PYTHON $gen_filelist --srcdir $srcdir --outlist $trainlist

# Split trainlist for parallel processing
splitdir=${tgtroot}/split${nj}
mkdir -p ${splitdir}/log
split_scp.pl ${trainlist} $(for j in $(seq ${nj}); do echo ${splitdir}/train.${j}.list; done)

# Create a JSON file for the source data set. (~10 min with nj=32)
trainjson=$tgtroot/train.json
${gen_cmd} JOB=1:${nj} ${splitdir}/log/list2json.JOB.log \
    $PYTHON $list2json --input_list ${splitdir}/train.JOB.list --output_file ${splitdir}/train.JOB.json

$PYTHON $mergejson $(for j in $(seq ${nj}); do echo ${splitdir}/train.${j}.json; done) > $trainjson

# Generate mixture specs. 
tgtdir=$tgtroot/wav
specjson=$tgtroot/mixspec.json
$PYTHON $mixspec --inputfile $trainjson --outputfile $specjson --ncopies $ncopies --single_speaker_percentage $single_spkr --targetdir $tgtdir

# Split $tgtroot/mixspec.json into several smaller json files: $splitdir/mixspec.JOB.json
$PYTHON $splitjson --inputfile $specjson --number_splits $nj --outputdir $splitdir

# Generate mixed audio files. 
mixlog=$tgtroot/mixlog.json
${gen_cmd} JOB=1:${nj} ${splitdir}/log/mixlog.JOB.log \
    $PYTHON $mixer --iolist ${splitdir}/mixspec.JOB.json --cancel_dcoffset --random_seed $rndseed --mixers_configfile $cfgfile --sample_rate 16000 --log ${splitdir}/mixlog.JOB.json
$PYTHON $mergejson $(for j in $(seq ${nj}); do echo ${splitdir}/mixlog.${j}.json; done) > $mixlog
