#/bin/bash
INDEX_MONTH=`date +"%Y.%m"`
ELASTIC_ADDR=127.0.0.1:9200
INDEX_PREFIX=filebeat-6.8.13-
DATA_FILE=cmd.dat
URL_SEND_CMD="curl -s"

if [ "$#" -eq 1 ]; then
  INDEX_MONTH="$1"
fi

INDEX_DATE_LIST=`$URL_SEND_CMD -XGET $ELASTIC_ADDR/_cat/indices | grep close | grep $INDEX_PREFIX$MONTH | awk -F "$INDEX_PREFIX" '{print $2}'  | awk '{print $1}' | sort -r`
echo "{ \"transient\" : { \"cluster.routing.rebalance.enable\" : \"none\" }}" > $DATA_FILE
$URL_SEND_CMD -XPUT -H 'Content-Type: application/json' $ELASTIC_ADDR/_cluster/settings --data-binary @$DATA_FILE
rm -f $DATA_FILE
for INDEX_DATE in $INDEX_DATE_LIST
do
    INDEX_NAME="$INDEX_PREFIX$INDEX_DATE"
    DATE=`date +"%Y%m%d_%H%M%S"`
    echo "$DATE [$INDEX_NAME] index is opening" 
    $URL_SEND_CMD -XPOST http://$ELASTIC_ADDR/$INDEX_NAME/_open
    echo ""
    while [ 1 ]
    do
        CNT=`$URL_SEND_CMD -s -XGET $ELASTIC_ADDR/_cat/shards/$INDEX_NAME | grep -v STARTED | wc | cut -c7-8`
        DATE=`date +"%Y%m%d_%H%M%S"`
        echo "$DATE CNT : $CNT"
        if [ $CNT -eq 0 ]
        then
            DATE=`date +"%Y%m%d_%H%M%S"`
            echo "$DATE [$INDEX_NAME] index is opened"
            break
        fi
        sleep 5
    done
done
echo "{ \"transient\" : { \"cluster.routing.rebalance.enable\" : \"all\" } }" > $DATA_FILE
$URL_SEND_CMD -XPUT -H 'Content-Type: application/json' $ELASTIC_ADDR/_cluster/settings --data-binary @$DATA_FILE
rm -f $DATA_FILE
