#!/bin/sh

rm -rf ../../aws-mturk-clt-1.3.1/samples/__bettercount
cp -r __bettercount ../../aws-mturk-clt-1.3.1/samples/
cp ../../aws-mturk-clt-1.3.1/bin/mturk.properties.jq ../../aws-mturk-clt-1.3.1/bin/mturk.properties
cd ../../aws-mturk-clt-1.3.1/samples/__bettercount
./run.sh