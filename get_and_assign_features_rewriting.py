import argparse
import fileinput
import spacy
import pickle
import sys
import pdb

parser = argparse.ArgumentParser(description='Optional app description')
nlp = spacy.load('en')
nlp.max_length =  2000000
parser.add_argument('--file_path', type=str)
parser.add_argument('--save_dir', type=str)
parser.add_argument('--target_language', type=str)
parser.add_argument('--split', type=str)

args = parser.parse_args()

path = str(args.file_path)
save_dir = str(args.save_dir)
target_language = str(args.target_language)
split = str(args.split)

byte_level_vbar = b'\xef\xbf\xa8'
string_vbar = byte_level_vbar.decode('utf-8')

POS_list = []
case_list = []
for c, line in enumerate(fileinput.input(path, inplace=True, mode ='rb')):
  temp = line.decode('utf-8')
  doc = nlp(str(temp))
  encoded_sentence = ' '.join([str(token) for token in doc])
  POS_list.append([token.pos_ for token in doc[:-1]])
  case_list.append([str(int(str(token.text)[0].isupper())) for token in doc[:-1]])
  sys.stdout.write(encoded_sentence)

fileinput.close()

assert len(POS_list) == len(case_list)
print(f"Created POS and case lists for {len(POS_list)} sentences")

with open(f'{save_dir}/POS_list_en-{target_language}_{split}.pkl', 'wb') as f:
  pickle.dump(POS_list, f)
with open(f'{save_dir}/case_list_en-{target_language}_{split}.pkl', 'wb') as f:
  pickle.dump(case_list, f)
