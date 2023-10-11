#!/bin/sh

LOGFILE="elastic_relocate.log"
CMD_FILE=data_file.dat
CMD_RESULT_FILE=result_file.dat
ELASTIC_ADDR=127.0.0.1:9200
PREFIX="filebeat-6.8.13-"
URL_SEND_CMD="curl -s"

BEFOREDAY=`date -v-1d +"%Y%m%d"`
if [ $# -eq 1 ]
then
        BEFOREDAY=$1
fi

INDEX_NAME="$PREFIX$BEFOREDAY"

TOTAL_SHARD_COUNT=`$URL_SEND_CMD $ELASTIC_ADDR/_cat/shards | grep $INDEX_NAME  | wc -l`
TOTAL_STARTED_SHARD_COUNT=`$URL_SEND_CMD $ELASTIC_ADDR/_cat/shards | grep $INDEX_NAME  | grep STARTED | wc -l`
TOTAL_UNSIGNED_SHARD_COUNT=`$URL_SEND_CMD $ELASTIC_ADDR/_cat/shards | grep $INDEX_NAME  | grep UNASSIGNED | wc -l`
TOTAL_NODE_COUNT=`$URL_SEND_CMD $ELASTIC_ADDR/_cat/nodes?h=node.role | grep d | wc | awk '{print $1}'`
SHARD_PER_NODE=$((TOTAL_SHARD_COUNT/TOTAL_NODE_COUNT))
MAX_SHARD_NUMBER=`$URL_SEND_CMD $ELASTIC_ADDR/_cat/shards | grep $INDEX_NAME | awk '{print $2}' | sort | tail -n 1`

TOTAL_SUM_SHARD_COUNT=$((TOTAL_STARTED_SHARD_COUNT+TOTAL_UNSIGNED_SHARD_COUNT))
if [ $TOTAL_UNSIGNED_SHARD_COUNT -gt 0 ] && [ $TOTAL_SHARD_COUNT -eq $TOTAL_SUM_SHARD_COUNT ]
then
        echo "============================================================" >> $LOGFILE
        echo "$INDEX_NAME Relocation is Started" >> $LOGFILE
        date >> $LOGFILE
        echo "------------------------------------------------------------" >> $LOGFILE

        DATE=`date +"%Y%m%d_%H%M%S"`
        echo "$DATE [$INDEX_NAME] Relocation is started" >> $LOGFILE
        TARGET_SHARD_DATA_NODES=`$URL_SEND_CMD $ELASTIC_ADDR/_cat/shards | grep $INDEX_NAME | grep -v UNASSIGNED | awk '{print $8}' | sort | uniq -c | awk -v shard_per_node="$SHARD_PER_NODE" '$1 < shard_per_node {print $2}'`
        for TARGET_DATA_NODE in $TARGET_SHARD_DATA_NODES
        do
                TARGET_NODE_SHARDS=`$URL_SEND_CMD $ELASTIC_ADDR/_cat/shards | grep $INDEX_NAME | grep $TARGET_DATA_NODE | awk '{print $2}'  | sort`
                SOURCE_SHARD=-1
                while [ 1 ]
                do
                        #Linux 
                        #RANDOM_IDX=`shuf -i0-$MAX_SHARD_NUMBER -n1`
                        #MacOS
                        RANDOM_IDX=`jot -r 1 0 $MAX_SHARD_NUMBER`
                        CHECK_EXIST=`echo $TARGET_NODE_SHARDS | grep $RANDOM_IDX | wc | cut -c7-8`
                        if [ $CHECK_EXIST == "0" ]
                        then
                                SOURCE_SHARD=$RANDOM_IDX
                                break
                        fi
                done
                SOURCE_DATA_NODE=`$URL_SEND_CMD $ELASTIC_ADDR/_cat/shards | grep $INDEX_NAME | egrep -e " $SOURCE_SHARD ( )?r STARTED"  | awk '{print $8}'`
                DATE=`date +"%Y%m%d_%H%M%S"`
                echo "$DATE [$INDEX_NAME] shard is relocating for unassigned shard : SHARD($SOURCE_SHARD), FROM($SOURCE_DATA_NODE), TO($TARGET_DATA_NODE)" >> $LOGFILE
                CMD=`echo "{\"commands\" : [ {\"move\" : { \"index\" : \"$INDEX_NAME\", \"shard\" : $SOURCE_SHARD, \"from_node\" : \"$SOURCE_DATA_NODE\", \"to_node\" : \"$TARGET_DATA_NODE\" } } ]}"`
                echo "$CMD" > $CMD_FILE
                echo "" >> $CMD_RESULT_FILE
                $URL_SEND_CMD -H 'Content-Type: application/json' -XPOST $ELASTIC_ADDR/_cluster/reroute?pretty --data-binary "@$CMD_FILE" >> $CMD_RESULT_FILE
                sleep 5
        done
        echo "============================================================" >> $LOGFILE
        echo "$INDEX_NAME Relocation is Finished" >> $LOGFILE
        date >> $LOGFILE
        echo "------------------------------------------------------------" >> $LOGFILE
fi
