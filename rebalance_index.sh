LOGFILE="elastic_rebalance.log"
ELASTIC=127.0.0.1:9200
PREFIX="filebeat-6.8.13-"
CURL_CMD="curl -s"
DATA_FILE="reroute_data_file.dat"
PRIMARY_SHARD_COUNT=2

BEFOREDAY=`date -v-1d "+%Y.%m.%d"`
if [ $# -eq 1 ]
then
        BEFOREDAY=$1
fi

INDEX_NAME="$PREFIX$BEFOREDAY"

echo "============================================================" >> $LOGFILE
echo "$INDEX_NAME Primary Shard Reblance is Started" >> $LOGFILE
date >> $LOGFILE
echo "------------------------------------------------------------" >> $LOGFILE

ELASTIC_NODE_LIST=`$CURL_CMD $ELASTIC/_cat/nodes | grep d | awk '{print $8}' | sort`
for ELASTIC_NODE in $ELASTIC_NODE_LIST
do
        echo "$ELASTIC_NODE"
        PRIMARY_COUNT=`$CURL_CMD $ELASTIC/_cat/shards/$INDEX_NAME | grep $ELASTIC_NODE | grep " p STARTED" | wc | cut -c7-8 | xargs`
        REPLICA_COUNT=`$CURL_CMD $ELASTIC/_cat/shards/$INDEX_NAME | grep $ELASTIC_NODE | grep " r STARTED" | wc | cut -c7-8 | xargs`
        DATE=`date +"%Y%m%d_%H%M%S"`
        echo "$DATE [$INDEX_NAME] Node Infomation : NODE($ELASTIC_NODE), PRIMARY_COUNT($PRIMARY_COUNT), REPLICA_COUNT($REPLICA_COUNT)" >> $LOGFILE
        if [ "$REPLICA_COUNT" -gt "$PRIMARY_COUNT" ]
        then
                SHARD_LIST=`$CURL_CMD $ELASTIC/_cat/shards/$INDEX_NAME | grep $ELASTIC_NODE | grep " r STARTED" | awk '{print $2}'`
                for SHARD in $SHARD_LIST
                do
                        DATE=`date +"%Y%m%d_%H%M%S"`
                        echo "$DATE [$INDEX_NAME] Shard Primary Replica Swap Check : NODE($ELASTIC_NODE), SHARD($SHARD)" >> $LOGFILE
                        NODE_HAVE_PRIMARY_SHARD=`$CURL_CMD $ELASTIC/_cat/shards/$INDEX_NAME | egrep " $SHARD ? p STARTED" | awk '{print $8}'`
                        SRC_NODE=`echo "$ELASTIC_NODE" | cut -c1-17`
                        DST_NODE=`echo "$NODE_HAVE_PRIMARY_SHARD" | cut -c1-17`
                        if [[ "$SRC_NODE" < "$DST_NODE" ]]
                        then
                                PRIMARY_SHARD_COUNT=`$CURL_CMD $ELASTIC/_cat/shards/$INDEX_NAME | grep $NODE_HAVE_PRIMARY_SHARD | grep " p STARTED" | wc | cut -c7-8`
                                if [ $PRIMARY_SHARD_COUNT -gt $PRIMARY_SHARD_COUNT ]
                                then
                                        DATE=`date +"%Y%m%d_%H%M%S"`
                                        echo "$DATE [$INDEX_NAME] Shard Primary Replica Swap is started : NODE($ELASTIC_NODE), NODE($NODE_HAVE_PRIMARY_SHARD), SHARD($SHARD)" >> $LOGFILE
                                        echo "{ \"commands\" : [ { \"cancel\" : { \"index\" : \"$INDEX_NAME\", \"shard\" : $SHARD, \"node\" : \"$NODE_HAVE_PRIMARY_SHARD\", \"allow_primary\": true    } } ] }" > $DATA_FILE
                                        RESULT=`$CURL_CMD -XPOST $ELASTIC/_cluster/reroute?pretty -H 'Content-Type: application/json' --data-binary @$DATA_FILE`
                                        while [ 1 ]
                                        do
                                                CNT=`$CURL_CMD $ELASTIC/_cat/shards/$INDEX_NAME | grep $ELASTIC_NODE | egrep " $SHARD ? p STARTED" | wc | cut -c7-8`
                                                if [ $CNT -eq 1 ]
                                                then
                                                        break;
                                                fi
                                                sleep 1
                                        done
                                        DATE=`date +"%Y%m%d_%H%M%S"`
                                        echo "$DATE [$INDEX_NAME] Shard Primary Replica Swap is finished : NODE($ELASTIC_NODE), NODE($NODE_HAVE_PRIMARY_SHARD), SHARD($SHARD)" >> $LOGFILE
                                fi
                                PRIMARY_COUNT=`$CURL_CMD $ELASTIC/_cat/shards/$INDEX_NAME | grep $ELASTIC_NODE | grep " p STARTED" | wc | cut -c7-8`
                                REPLICA_COUNT=`$CURL_CMD $ELASTIC/_cat/shards/$INDEX_NAME | grep $ELASTIC_NODE | grep " r STARTED" | wc | cut -c7-8`
                                if [ "$REPLICA_COUNT" -eq "$PRIMARY_COUNT" ]
                                then
                                        break
                                fi
                        fi
                done
        elif [ "$REPLICA_COUNT" -lt "$PRIMARY_COUNT" ]
        then
                SHARD_LIST=`$CURL_CMD $ELASTIC/_cat/shards/$INDEX_NAME | grep $ELASTIC_NODE | grep " p STARTED" | awk '{print $2}'`
                for SHARD in $SHARD_LIST
                do
                        DATE=`date +"%Y%m%d_%H%M%S"`
                        echo "$DATE [$INDEX_NAME] Shard Primary Replica Swap Check : NODE($ELASTIC_NODE), SHARD($SHARD)" >> $LOGFILE
                        NODE_HAVE_REPLICA_SHARD=`$CURL_CMD $ELASTIC/_cat/shards/$INDEX_NAME | egrep " $SHARD ? r STARTED" | awk '{print $8}'`
                        SRC_NODE=`echo "$ELASTIC_NODE" | cut -c1-17`
                        DST_NODE=`echo "$NODE_HAVE_REPLICA_SHARD" | cut -c1-17`
                        if [[ "$SRC_NODE" < "$DST_NODE" ]]
                        then
                                REPLICA_SHARD_COUNT=`$CURL_CMD $ELASTIC/_cat/shards/$INDEX_NAME | grep $NODE_HAVE_REPLICA_SHARD | grep " r STARTED" | wc | cut -c7-8`
                                if [ $REPLICA_SHARD_COUNT -gt $PRIMARY_SHARD_COUNT ]
                                then
                                        DATE=`date +"%Y%m%d_%H%M%S"`
                                        echo "$DATE [$INDEX_NAME] Shard Primary Replica Swap is started : NODE($ELASTIC_NODE), NODE($NODE_HAVE_PRIMARY_SHARD), SHARD($SHARD)" >> $LOGFILE
                                        echo "{ \"commands\" : [ { \"cancel\" : { \"index\" : \"$INDEX_NAME\", \"shard\" : $SHARD, \"node\" : \"$ELASTIC_NODE\", \"allow_primary\": true    } } ] }" > $DATA_FILE
                                        RESULT=`$CURL_CMD -XPOST $ELASTIC/_cluster/reroute?pretty -H 'Content-Type: application/json' --data-binary @$DATA_FILE`
                                        while [ 1 ]
                                        do
                                                CNT=`$CURL_CMD $ELASTIC/_cat/shards/$INDEX_NAME | grep $ELASTIC_NODE | egrep " $SHARD ? r STARTED" | wc | cut -c7-8`
                                                if [ $CNT -eq 1 ]
                                                then
                                                        break;
                                                fi
                                                sleep 1
                                        done
                                        DATE=`date +"%Y%m%d_%H%M%S"`
                                        echo "$DATE [$INDEX_NAME] Shard Primary Replica Swap is finished : NODE($ELASTIC_NODE), NODE($NODE_HAVE_PRIMARY_SHARD), SHARD($SHARD)" >> $LOGFILE
                                fi
                                PRIMARY_COUNT=`$CURL_CMD $ELASTIC/_cat/shards/$INDEX_NAME | grep $ELASTIC_NODE | grep " p STARTED" | wc | cut -c7-8`
                                REPLICA_COUNT=`$CURL_CMD $ELASTIC/_cat/shards/$INDEX_NAME | grep $ELASTIC_NODE | grep " r STARTED" | wc | cut -c7-8`
                                if [ "$REPLICA_COUNT" -eq "$PRIMARY_COUNT" ]
                                then
                                        break
                                fi
                        fi
                done
        else
                echo "EQUEL"
        fi
        SRC_NODE=`echo "$ELASTIC_NODE" | cut -c1-17`
done

echo "============================================================" >> $LOGFILE
echo "$INDEX_NAME Primary Shard Reblance is Stoped" >> $LOGFILE
date >> $LOGFILE
echo "------------------------------------------------------------" >> $LOGFILE


