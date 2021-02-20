#!/bin/bash
INDEX_DATE=`date -v-1d +"%Y.%m.%d"`
ELASTIC_ADDR=127.0.0.1:9200
INDEX_PREFIX=filebeat-6.8.13-
NUM_SEGMENT=10

if [ "$#" -eq 1 ]; then
  INDEX_DATE="$1"
fi

echo "$INDEX_PREFIX$INDEX_DATE will be forcemerged"
curl -XPOST "http://$ELASTIC_ADDR/$INDEX_PREFIX$INDEX_DATE/_forcemerge?max_num_segments=$NUM_SEGMENT" | python -m json.tool
echo ""
