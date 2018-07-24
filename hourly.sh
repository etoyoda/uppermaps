#!/bin/sh

cd `/usr/bin/dirname $0`

set -e

cutoff=40
timecard=`/usr/bin/ruby -e "puts((Time.now - $cutoff * 60).strftime('%Y %m %d %H 00'))"`

if test -d tmp
then
  test ! -d tmp.prev || rm -rf tmp.prev
  mv tmp tmp.prev
  echo found work directory by previous run for $(cat tmp/timecard.txt).
fi
mkdir tmp
echo $timecard > tmp/timecard.txt

(cd tmp ; sh -$- local-collect.sh $timecard 'A_IUPC[45][0-9]RJTD')
for bufr in tmp/A*.bufr
do
bufr_decoder -dump -output tmp/z.txt -inbufr $bufr
cat tmp/z.txt >> tmp/wpjp.txt 
done
ruby wpdecode.rb tmp/wpjp.txt > wpjp.json

test -f tmp.keep || rm -rf tmp
