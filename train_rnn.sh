#!/bin/bash

# E.g.: /work/vas11/NLP/lowrestxformer/data
DATA_PATH=$1

# E.g.: "fr de zh_cn ko si"
LANGUAGES=$2

# E.g.: /work/vas11/NLP/lowrestxformer/results
RESULTS_PATH=$3/rnn

if [ ! -d OpenNMT-py ]; then
	pip install OpenNMT-py
	git clone https://github.com/OpenNMT/OpenNMT-py.git
fi

sl=en
# ablations='base pos_case_sp pos case sp pos_case pos_sp case_sp' # commented out since we're not doing a full ablation study
ablations='base pos_case_sp'
checkpoints='5000 10000 15000 20000 25000 30000 35000 40000 45000 50000'

for ablation in $ablations
do
	for tl in $LANGUAGES
	do	
		if [ -d $RESULTS_PATH/$sl-$tl/$ablation ]; then
			echo "$RESULTS_PATH/$sl-$tl/$ablation already exists"
			break
		fi
		
		if [ ! -d $RESULTS_PATH/$sl-$tl/$ablation ]; then
			mkdir -p $RESULTS_PATH/$sl-$tl/$ablation
		fi
		
		echo "Preprocessing $sl-$tl, $ablation for OpenNMT"
		
		python OpenNMT-py/preprocess.py \
		-overwrite \
		-train_src $DATA_PATH/$sl-$tl/OpenSubtitles.$sl-$tl.$sl.sptrain.${ablation} \
		-train_tgt $DATA_PATH/$sl-$tl/OpenSubtitles.$sl-$tl.$tl.sptrain \
		-valid_src $DATA_PATH/$sl-$tl/OpenSubtitles.$sl-$tl.$sl.spvalid.${ablation} \
		-valid_tgt $DATA_PATH/$sl-$tl/OpenSubtitles.$sl-$tl.$tl.spvalid \
		-save_data $DATA_PATH/$sl-$tl/OpenSubtitles.$sl-$tl.data.${ablation} \
		-src_seq_length 100 -tgt_seq_length 100 -shard_size 200000000 -share_vocab 2>&1 | \
		tee $RESULTS_PATH/$sl-$tl/$ablation/terminal_output_preprocess.txt

		echo "Training $sl-$tl, $ablation for OpenNMT"

		python OpenNMT-py/train.py \
		-data $DATA_PATH/$sl-$tl/OpenSubtitles.$sl-$tl.data.${ablation} \
		-save_model $RESULTS_PATH/$sl-$tl/$ablation/model \
		-rnn_size 512 \
		-src_word_vec_size 512 -tgt_word_vec_size 512 \
		-encoder_type rnn -decoder_type rnn \
		-train_steps 50000 \
		-dropout 0.1 \
		-feat_merge sum \
		-valid_steps 2500 -save_checkpoint_steps 5000 \
		-world_size 1 -gpu_ranks 0 2>&1 | \
		tee $RESULTS_PATH/$sl-$tl/$ablation/terminal_output_train.txt

		for checkpoint in $checkpoints
		do
			echo "Translating $sl-$tl, $ablation"
			
			python OpenNMT-py/translate.py \
			-model $RESULTS_PATH/$sl-$tl/$ablation/model_step_$checkpoint.pt \
			-src $DATA_PATH/$sl-$tl/OpenSubtitles.$sl-$tl.$sl.sptest.${ablation} \
			-output $RESULTS_PATH/$sl-$tl/$ablation/translation_$checkpoint.txt \
			-replace_unk \
			-verbose
			
			echo "Evaluating $sl-$tl, $ablation"
			
			perl OpenNMT-py/tools/multi-bleu.perl \
			$DATA_PATH/$sl-$tl/OpenSubtitles.$sl-$tl.$tl.sptest < \
			$RESULTS_PATH/$sl-$tl/$ablation/translation_$checkpoint.txt 2>&1 | \
			tee $RESULTS_PATH/$sl-$tl/$ablation/translation_bleu_$checkpoint.txt
		done
	done
done
