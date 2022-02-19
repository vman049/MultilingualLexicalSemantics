#!/bin/bash

# E.g.: /work/vas11/NLP/lowrestxformer/data
DATA_PATH=$1

# E.g.: "fr de zh_cn ko si"
LANGUAGES=$2

# E.g.: /hpc/group/nicolab/vas11/sentencepiece/bin
SP_PATH=$3

# E.g.: /hpc/group/nicolab/vas11/sentencepiece/lib
LD_LIBRARY_PATH_TEMP=$4

### Determine how many sentences are going to be in the training, validation, and testing datasets by finding the language pair with the minimum number of parallel sentences and setting this to be the number of samples for all language pairs. ###

# if num_lines.txt exists, remove it
rm -f num_lines.txt

# count the number of lines in each sl-tl pair and store them in a file called num_lines.txt
sl=en
for tl in $LANGUAGES
do
	# wc -l < $DATA_PATH/$sl-$tl/OpenSubtitles.$sl-$tl.$tl | cat >> num_lines.txt
	wc -l $DATA_PATH/$sl-$tl/OpenSubtitles.$sl-$tl.$tl | cat >> num_lines.txt
done

# store the minimum of these in a variable called num_lines; this is the number of lines that comprises the full training + validation + test set for each of the sl-tl pairs
num_lines=$(sort -n num_lines.txt | cut -d " " -f 1 | awk '{print $1; exit}')

# remove the num_lines.txt file
rm -f num_lines.txt

##### HARDCODED FOR DEBUGGING PURPOSES, DELETE BEFORE STARTING FINAL RUN #####
# num_lines=601164  # minimum number of lines across all five languages
num_lines=5000   # a small number of lines just for debugging

# denote indices for training, validation, and testing data
idx_train=$(($num_lines/20*14)) # 70% training
idx_valid=$(($num_lines/20*17)) # 15% validation
idx_test=$num_lines 			# 15% testing

echo "$idx_train training, $idx_valid validation, and $idx_test testing examples"

# shuffle data that falls in the first idx_test examples
for tl in $LANGUAGES
do
	echo "Shuffling $sl-$tl data"
	
	for l in $sl $tl
	do
		rm -f $DATA_PATH/$sl-$tl/shuffle_input.$l
		rm -f $DATA_PATH/$sl-$tl/shuffle_output.$l
		sed -n "1,${idx_test}p;$(($idx_test+1))q" $DATA_PATH/$sl-$tl/OpenSubtitles.$sl-$tl.$l > \
		$DATA_PATH/$sl-$tl/shuffle_input.$l
	done
	
	bash shuffle_parallel_corpora.sh \
	$DATA_PATH/$sl-$tl/shuffle_input.$sl $DATA_PATH/$sl-$tl/shuffle_input.$tl \
	$DATA_PATH/$sl-$tl/shuffle_output.$sl $DATA_PATH/$sl-$tl/shuffle_output.$tl 42
	
	for l in $sl $tl
	do
		tail -n +$((idx_test+1)) $DATA_PATH/$sl-$tl/OpenSubtitles.$sl-$tl.$l >> \
		$DATA_PATH/$sl-$tl/shuffle_output.$l
		cat $DATA_PATH/$sl-$tl/shuffle_output.$l > $DATA_PATH/$sl-$tl/OpenSubtitles.$sl-$tl.$l
		rm -f $DATA_PATH/$sl-$tl/shuffle_input.$l
		rm -f $DATA_PATH/$sl-$tl/shuffle_output.$l
	done
done

# Use spaCy to re-write the original lines with spaCy tokenization
for tl in $LANGUAGES
do
	rm -f $DATA_PATH/$sl-$tl/rewrite_with_spacy_$sl-${tl}_train.txt
	rm -f $DATA_PATH/$sl-$tl/rewrite_with_spacy_$sl-${tl}_valid.txt
	rm -f $DATA_PATH/$sl-$tl/rewrite_with_spacy_$sl-${tl}_test.txt
	
	
	### separate data into training, validation, and testing
	sed -n "1,${idx_train}p;$(($idx_train+1))q" $DATA_PATH/$sl-$tl/OpenSubtitles.$sl-$tl.$sl >> $DATA_PATH/$sl-$tl/rewrite_with_spacy_$sl-${tl}_train.txt
	python get_and_assign_features_rewriting.py --file_path $DATA_PATH/$sl-$tl/rewrite_with_spacy_$sl-${tl}_train.txt --save_dir $DATA_PATH/$sl-$tl --target_language $tl --split train
	cat $DATA_PATH/$sl-$tl/rewrite_with_spacy_$sl-${tl}_train.txt > $DATA_PATH/$sl-$tl/temp.txt
	
	
	sed -n "$(($idx_train+1)),${idx_valid}p;$(($idx_valid+1))q" $DATA_PATH/$sl-$tl/OpenSubtitles.$sl-$tl.$sl >> $DATA_PATH/$sl-$tl/rewrite_with_spacy_$sl-${tl}_valid.txt
	python get_and_assign_features_rewriting.py --file_path $DATA_PATH/$sl-$tl/rewrite_with_spacy_$sl-${tl}_valid.txt --save_dir $DATA_PATH/$sl-$tl --target_language $tl --split valid
	cat $DATA_PATH/$sl-$tl/rewrite_with_spacy_$sl-${tl}_valid.txt >> $DATA_PATH/$sl-$tl/temp.txt
	
	
	sed -n "$(($idx_valid+1)),${idx_test}p" $DATA_PATH/$sl-$tl/OpenSubtitles.$sl-$tl.$sl >> $DATA_PATH/$sl-$tl/rewrite_with_spacy_$sl-${tl}_test.txt
	python get_and_assign_features_rewriting.py --file_path $DATA_PATH/$sl-$tl/rewrite_with_spacy_$sl-${tl}_test.txt --save_dir $DATA_PATH/$sl-$tl --target_language $tl --split test
	cat $DATA_PATH/$sl-$tl/rewrite_with_spacy_$sl-${tl}_test.txt >> $DATA_PATH/$sl-$tl/temp.txt
	
	cat $DATA_PATH/$sl-$tl/temp.txt > $DATA_PATH/$sl-$tl/OpenSubtitles.$sl-$tl.$sl
	
	rm -f $DATA_PATH/$sl-$tl/temp.txt
	rm -f $DATA_PATH/$sl-$tl/rewrite_with_spacy_$sl-${tl}_train.txt
	rm -f $DATA_PATH/$sl-$tl/rewrite_with_spacy_$sl-${tl}_valid.txt
	rm -f $DATA_PATH/$sl-$tl/rewrite_with_spacy_$sl-${tl}_test.txt
done

# Train sentencepiece models for each of the language pairs, using only data from the training datasets

## set relevant paths
export PATH=$SP_PATH:$PATH
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH_TEMP:$LD_LIBRARY_PATH

## set vocabulary size
# vocab_size=32000
vocab_size=5567

## train model
for tl in $LANGUAGES
do
	echo "Training sentencepiece model for $sl-$tl"
	
	## remove training file if it exists
	rm -f $DATA_PATH/$sl-$tl/${sl}-${tl}_train.txt
	
	for f in $DATA_PATH/$sl-$tl/OpenSubtitles.$sl-$tl.$sl $DATA_PATH/$sl-$tl/OpenSubtitles.$sl-$tl.$tl
	do
		## concatenate both the source and target language training examples into one file
		sed -n "1,${idx_train}p;$(($idx_train+1))q" $f >> $DATA_PATH/$sl-$tl/${sl}-${tl}_train.txt
	done
	
	if [ ! -d $DATA_PATH/$sl-$tl/spm/ ]; then
		mkdir $DATA_PATH/$sl-$tl/spm/
	fi
	
	num_sp_lines=$(wc -l $DATA_PATH/$sl-$tl/${sl}-${tl}_train.txt)
	read -t 5 -p "Total number of lines (source plus target languages) for training sentencepiece model: $num_sp_lines"
	
	## train the sentencepiece model on only the training examples from both languages
	$SP_PATH/spm_train --input=$DATA_PATH/$sl-$tl/${sl}-${tl}_train.txt \
	  --hard_vocab_limit=false \
	  --model_prefix=$DATA_PATH/$sl-$tl/spm/spm_$sl-$tl \
	  --vocab_size=$vocab_size --character_coverage=1

	rm $DATA_PATH/$sl-$tl/${sl}-${tl}_train.txt
done

# Create sentencepiece output for source language using files rewritten with spaCy tokenizer output; also create sentencepiece output for target language using original files

for tl in $LANGUAGES
do
	## for the source language, use the files rewritten with spaCy tokenizer output
	## for the target language, use the original files
	for l in $sl $tl
	do
		echo "Encoding $sl-$tl: $l (sentencepiece)"
		echo "Creating training, validation, and testing data for $l"
		
		### separate data into training, validation, and testing
		sed -n "1,${idx_train}p;$(($idx_train+1))q" $DATA_PATH/$sl-$tl/OpenSubtitles.$sl-$tl.$l >> $DATA_PATH/$sl-$tl/OpenSubtitles.$sl-$tl.$l.train
		sed -n "$(($idx_train+1)),${idx_valid}p;$(($idx_valid+1))q" $DATA_PATH/$sl-$tl/OpenSubtitles.$sl-$tl.$l >> $DATA_PATH/$sl-$tl/OpenSubtitles.$sl-$tl.$l.valid
		sed -n "$(($idx_valid+1)),${idx_test}p" $DATA_PATH/$sl-$tl/OpenSubtitles.$sl-$tl.$l >> $DATA_PATH/$sl-$tl/OpenSubtitles.$sl-$tl.$l.test
		
		### for each split, encode with sentencepiece
		for split in train valid test
		do
			echo "Encoding $split data for $l in $sl-$tl pair"
			
			$SP_PATH/spm_encode --model=$DATA_PATH/$sl-$tl/spm/spm_$sl-$tl.model < $DATA_PATH/$sl-$tl/OpenSubtitles.$sl-$tl.$l.$split > $DATA_PATH/$sl-$tl/OpenSubtitles.$sl-$tl.$l.sp${split}
		done
	done
	
	echo "Postprocessing vocabulary for OpenNMT-TF"
	
	## Keep the first field of the vocab file generated by SentencePiece and remove the first line <unk>
	cut -f 1 $DATA_PATH/$sl-$tl/spm/spm_$sl-$tl.vocab | tail -n +2 > $DATA_PATH/$sl-$tl/spm/spm_$sl-$tl.vocab.tmp
	
	## Add the <blank> word in first position, needed for OpenNMT-TF
	sed -i '1i<blank>' $DATA_PATH/$sl-$tl/spm/spm_$sl-$tl.vocab.tmp
	
	## Last tweak we replace the empty line supposed to be the "tab" character (removed by the cut above)
	perl -pe '$/=""; s/\n\n/\n\t\n/;' $DATA_PATH/$sl-$tl/spm/spm_$sl-$tl.vocab.tmp > $DATA_PATH/$sl-$tl/spm/spm_$sl-$tl.vocab
	rm $DATA_PATH/$sl-$tl/spm/spm_$sl-$tl.vocab.tmp
done

# Create source language base dataset (no features) by copying the output of sentencepiece above

for tl in $LANGUAGES
do
	for split in train valid test
	do
		cp $DATA_PATH/$sl-$tl/OpenSubtitles.$sl-$tl.$sl.sp${split} $DATA_PATH/$sl-$tl/OpenSubtitles.$sl-$tl.$sl.sp${split}.base
	done
done

# Create source language datasets with features, i.e., for the source language, append POS, case, and/or subword position features to the sentencepiece output, depending on the type of ablation; for convenience, we only consider the full set of features

for tl in $LANGUAGES
do
	## first, add POS and case features
	for split in train valid test
	do
		### since we're not doing an ablation study, the extension of the copied file is hardcoded as pos_case_sp;
		### if we were to do the full ablation study, each ablation would have its own file with its own extension (i.e., pos, case, sp, pos_case, pos_sp, case_sp, and pos_case_sp)
		cp $DATA_PATH/$sl-$tl/OpenSubtitles.$sl-$tl.$sl.sp${split} $DATA_PATH/$sl-$tl/OpenSubtitles.$sl-$tl.$sl.sp${split}.pos_case_sp
		
		### save_dir should match that of get_and_assign_features_rewriting.py above
		python assign_features_to_rewritten_subwords.py --file_path $DATA_PATH/$sl-$tl/OpenSubtitles.$sl-$tl.$sl.sp${split}.pos_case_sp --save_dir $DATA_PATH/$sl-$tl --target_language $tl --split $split
	done
	
	## subword position added after first adding POS and case features (ideally, this is all done in one Python script)
	for split in train valid test
	do
		python subwords_features_pos_case_location.py --file_path $DATA_PATH/$sl-$tl/OpenSubtitles.$sl-$tl.$sl.sp${split}.pos_case_sp
	done
done
