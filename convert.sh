#!/bin/bash
mkdir -p log
file_list=`find ../../protocol/ -name *.proto -type f|xargs file -i|grep "iso-8859-1"|awk -F ":" '{print $1}'`
for v in ${file_list}
do
	iconv -f iso-8859-1 -t utf8 ${v} -o ${v}
done
./convert_data.sh
./convert_pb.sh
cd protobufluaint64
./convert.sh
cd ..
for v in ${file_list}
do
	iconv -f utf8 -t iso-8859-1 ${v} -o ${v}
done