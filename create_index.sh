#!/bin/bash
INDEX_DATE=`date -v+1d +"%Y.%m.%d"`
ELASTIC_ADDR=127.0.0.1:9200
INDEX_PREFIX=filebeat-6.8.13-

if [ "$#" -eq 1 ]; then
  INDEX_DATE="$1"
fi

curl -XPUT "http://$ELASTIC_ADDR/$INDEX_PREFIX$INDEX_DATE"
echo ""
