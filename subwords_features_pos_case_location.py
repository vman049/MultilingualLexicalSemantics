import argparse
import fileinput
import sys
import pdb

parser = argparse.ArgumentParser(description='Optional app description')

parser.add_argument('--file_path', type=str,
                    help='A required integer positional argument')

args = parser.parse_args()

path = str(args.file_path)

byte_level_vbar = b'\xef\xbf\xa8'
string_vbar = byte_level_vbar.decode('utf-8')

for c,line in enumerate(fileinput.input(path, inplace=True, mode ='rb')):
  temp  = line.decode('utf-8')
  line1 = str(temp)[0:-1]
  listsplit = line1.split(" ")
  
  for idx, i in enumerate(listsplit):
    if len(i.split(string_vbar)) > 1:
      poss = i.split(string_vbar)[1]
      casee = i.split(string_vbar)[2]
      if idx+1 < len(listsplit):
        if len(listsplit[idx+1].split(string_vbar)) > 1:
            mystr = 'O'
        else:
            mystr = 'S'
      else:
        mystr = 'O'
      temp_i = i.replace(i, i + string_vbar + mystr)		
    else:
      if idx+1 < len(listsplit):
        if len(listsplit[idx+1].split(string_vbar)) > 1:
          mystr = 'E'
        else:
          mystr = 'M'
      else:
        mystr = 'E'
      temp_i = i.replace(i, i + string_vbar + poss.strip() + string_vbar + casee.strip() + string_vbar + mystr)
    listsplit[idx] = temp_i
  
  encoded_sentence = ' '.join(listsplit) + '\n'
  sys.stdout.write(encoded_sentence)
	
fileinput.close()
