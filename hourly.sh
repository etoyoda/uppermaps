#!/bin/sh

cd `/usr/bin/dirname $0`

cutoff=40
timecard=`/usr/bin/ruby -e "puts((Time.now - $cutoff * 60).strftime('%Y %m %d %H 00'))"`

test -d tmp || mkdir tmp
(cd tmp ; sh -$- local-collect.sh $timecard 'A_IUPC[45][0-9]RJTD')

for bufr in tmp/A*.bufr
do
bufr_decoder -dump -output tmp/z.txt -inbufr $bufr
cat tmp/z.txt >> tmp/iupcrjtd.txt 
done
ruby wpdecode.rb tmp/iupcrjtd.txt > wpjp.json
