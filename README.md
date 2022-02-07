# MultilingualLexicalSemantics

Code to train, translate, and evaluate models. To run this code, first download and extract the data from http://opus.nlpl.eu/OpenSubtitles-v2018.php. For example, for EN-BN, use the commands:

```
$ mkdir -p data/en-bn \&\& cd data/en-bn
$ wget http://opus.nlpl.eu/download.php?f=OpenSubtitles/v2018/moses/bn-en.txt.zip
$ unzip *.zip
```

Then, run the `run.sh` script with options to specify the location of the data, location of the generated results (will be created if it does not exist), and location of `sentencepiece` installation:

```
bash run.sh data ``bn'' sentencepiece/bin sentencepiece/lib results
```
