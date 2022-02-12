#!/bin/bash

# complete command
# bash run.sh /work/vas11/NLP/lowrestxformer/data "fr si" /hpc/group/nicolab/vas11/sentencepiece/bin /hpc/group/nicolab/vas11/sentencepiece/lib /work/vas11/NLP/lowrestxformer/results 2>&1 | tee /work/vas11/NLP/lowrestxformer/terminal_output.txt

# E.g.: /work/vas11/NLP/lowrestxformer/data
DATA_PATH=$1
# rm -r $DATA_PATH
cp -r ${DATA_PATH}_orig $DATA_PATH

# E.g.: "fr de zh_cn ko si"
LANGUAGES=$2

# E.g.: /hpc/group/nicolab/vas11/sentencepiece/bin
SP_PATH=$3

# E.g.: /hpc/group/nicolab/vas11/sentencepiece/lib
LD_LIBRARY_PATH_TEMP=$4

# E.g.: /work/vas11/NLP/lowrestxformer/results
RESULTS_PATH=$5

# bash create_dataset.sh $DATA_PATH "$LANGUAGES"
bash preprocess_dataset.sh $DATA_PATH "$LANGUAGES" $SP_PATH $LD_LIBRARY_PATH_TEMP
bash train_txformer.sh $DATA_PATH "$LANGUAGES" $RESULTS_PATH
bash train_rnn.sh $DATA_PATH "$LANGUAGES" $RESULTS_PATH
