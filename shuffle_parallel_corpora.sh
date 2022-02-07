#!/bin/bash

echo 'Input file 1 is: '+$1
echo 'Input file 2 is: '+$2
echo 'Output file 1 is: '+$3
echo 'Output file 2 is: '+$4
echo 'Random seed is: '+$5

get_seeded_random()
{
  seed="$1"
  openssl enc -aes-256-ctr -pass pass:"$seed" -nosalt \
    </dev/zero 2>/dev/null
}

shuf $1 --random-source=<(get_seeded_random $5) > $3
shuf $2 --random-source=<(get_seeded_random $5) > $4
