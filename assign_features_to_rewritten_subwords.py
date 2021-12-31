import argparse
import fileinput
import pickle
import sys
import pdb

parser = argparse.ArgumentParser(description='Optional app description')
parser.add_argument('--file_path', type=str,
                    help='A required integer positional argument')
parser.add_argument('--save_dir', type=str)
parser.add_argument('--target_language', type=str)
parser.add_argument('--split', type=str)

args = parser.parse_args()

path = str(args.file_path)
save_dir = str(args.save_dir)
target_language = str(args.target_language)
split = str(args.split)

new_word_identifier= b'\xe2\x96\x81'
byte_level_vbar = b'\xef\xbf\xa8'
string_vbar = byte_level_vbar.decode('utf-8')
string_new_word_identifier = new_word_identifier.decode('utf-8')

with open(f"{save_dir}/POS_list_en-{target_language}_{split}.pkl", 'rb') as f:
  POS_lists = pickle.load(f)
with open(f"{save_dir}/case_list_en-{target_language}_{split}.pkl", 'rb') as f:
  case_lists = pickle.load(f)

for c, (line, POS_list, case_list) in enumerate(zip(fileinput.input(path, inplace=True, mode ='rb'), POS_lists, case_lists)):
  temp  = line.decode('utf-8')
  encoded_sentence = ''
  idx = -1
  for token in temp.split(" "):
    if token[-1] == '\n':
      token = token[:-1]
    if token[0] == string_new_word_identifier:
      idx += 1
      encoded_sentence += token + string_vbar + POS_list[idx] + string_vbar + case_list[idx] + ' '
    else:
      encoded_sentence += token + ' '
  print(encoded_sentence[:-1])

fileinput.close()

# pdb.set_trace()
# poss = ' '
# casee= ' '
# for c,line in enumerate(fileinput.input(path, inplace=True, mode ='rb')):
  # #print(line)
  # temp  = line.decode('utf-8')
  # line1 = str(temp)[0:-1]
  # listsplit = line1.split(" ")[::-1]
     
  # #encoded_sentence = ''
  # for idx, i in enumerate(listsplit):
     # print(i)
     # if len(i.split(string_vbar)) > 1 :
       # poss = i.split(string_vbar)[1]
       # casee = i.split(string_vbar)[2]
       # if (idx < len(listsplit)-1):
         # if len(listsplit[idx+1].split(string_vbar)) > 1:
           # mystr = 'O'
         # else:
           # mystr = 'E'
       # else:
         # mystr = 'O'
       # temp_i = i.replace(i, i + string_vbar + mystr)
       # listsplit[idx] = temp_i
     # else:
       # if (idx < len(listsplit)-1):
         # if (len(listsplit[idx+1].split(string_vbar)) > 1):
           # mystr = 'S'
         # else:
           # mystr = 'M'
       # else:
         # mystr = 'S'
       # temp_i = i.replace(i, i + string_vbar + poss.strip() + string_vbar + casee.strip() + string_vbar + mystr)
       # listsplit[idx] = temp_i
  # #print(listsplit)
  # encoded_sentence = ' '.join(listsplit[::-1]) + '\n'
  # #temp  = line.decode('utf-8')
  # sys.stdout.write(encoded_sentence)
  # pdb.set_trace()
# fileinput.close()