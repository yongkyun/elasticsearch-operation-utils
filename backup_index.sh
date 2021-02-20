#!/bin/sh

## This script is tested on elasticsearch 6.8.13 version

## PREFIX : Index name's prefix
## CUR_ELASTIC : indexing cluster 
## BACKUP_ELASTIC : backup cluster  
## REPOSITORY_NAME : repository name, but indexing and blackup cluster have same and shared repository like nfs or hdfs
## LOGFILE : backup log file name 
## DATA_FILE : temparary file for elastic search command data
## BACKUP_ELASTIC_NUM_REPLICA : replica number of backup cluster
## BEFOREDAY : make date part of index name. If you use argument of shell, this part will be ignored

########### Fix this part for your environment - start ##########
PREFIX="filebeat-6.8.13-"
CUR_ELASTIC="127.0.0.1:9200"
BACKUP_ELASTIC="127.0.0.1:9210"
REPOSITORY_NAME="hot_backup"
URL_SEND_CMD="curl -s"
LOGFILE="elasticsearch_backup.log"
DATA_FILE="data_file.dat"
BACKUP_ELASTIC_NUM_REPLICA=1

BEFOREDAY=`date -v-10d +"%Y-%m-%d"`
########### Fix this part for your environment - end ##########

if [ $# -eq 1 ]
then
	BEFOREDAY=$1
fi

INDEX_NAME="$PREFIX$BEFOREDAY"

echo "============================================================" >> $LOGFILE
echo "$INDEX_NAME Backup is Started" >> $LOGFILE
date >> $LOGFILE
echo "------------------------------------------------------------" >> $LOGFILE

########## check index at backup cluster ##########
INDEX_CHECK_EXIST=`$URL_SEND_CMD -I -XHEAD http://$BACKUP_ELASTIC/$INDEX_NAME | grep HTTP | awk {'print $2'}`
if [ "$INDEX_CHECK_EXIST" == "200" ]
then
	DATE=`date +"%Y%m%d_%H%M%S"`
	echo "$DATE $INDEX_NAME is already exist at backup elasticsearch server($BACKUP_ELASTIC)" >> $LOGFILE
	exit
fi

########### check index at indexing cluster ##########
INDEX_CHECK_EXIST=`$URL_SEND_CMD -I -XHEAD http://$CUR_ELASTIC/$INDEX_NAME | grep HTTP | awk {'print $2'}`
if [ "$INDEX_CHECK_EXIST" != "200" ]
then 
	DATE=`date +"%Y%m%d_%H%M%S"`
	echo "$DATE $INDEX_NAME is not exist at current elasticsearch server($CUR_ELASTIC)" >> $LOGFILE
	exit
fi

INDEX_SIZE=`$URL_SEND_CMD -XGET http://$CUR_ELASTIC/_cat/indices/$INDEX_NAME?h=pri.store.size`

DATE=`date +"%Y%m%d_%H%M%S"`
echo "$DATE $INDEX_NAME Size : $INDEX_SIZE" >> $LOGFILE
echo "$DATE $INDEX_NAME Backup Repository : $REPOSITORY_NAME" >> $LOGFILE
	
########### make snapshut ##########
echo "{ \"indices\": \"$INDEX_NAME\", \"ignore_unavailable\": \"true\", \"include_global_state\": \"false\" }" > $DATA_FILE
RESULT=`$URL_SEND_CMD -XPUT -H 'Content-Type: application/json' http://$CUR_ELASTIC/_snapshot/$REPOSITORY_NAME/$INDEX_NAME --data-binary @$DATA_FILE`
rm -f $DATA_FILE

if [ "$RESULT" != "{\"accepted\":true}" ]
then
	DATE=`date +"%Y%m%d_%H%M%S"`
        echo "$DATE Fail to make $INDEX_NAME's snapshut : $RESULT" >> $LOGFILE
        exit
fi

########## check snapshut making ##########
DATE=`date +"%Y%m%d_%H%M%S"`
echo "$DATE $INDEX_NAME's snapshot making is started" >> $LOGFILE

while [ 1 ]
do
        STATE=`$URL_SEND_CMD -XGET http://$CUR_ELASTIC/_snapshot/$REPOSITORY_NAME/$INDEX_NAME?pretty | grep "\"state\"" | awk -F '"' '{print $4}'`
        DATE=`date +"%Y%m%d_%H%M%S"`
        if [ "$STATE" == "SUCCESS" ]
        then
                echo "$DATE $INDEX_NAME's snapshot making is succeed" >> $LOGFILE
                break;
	elif [ "$STATE" == "PARTIAL" ] || [ "$STATE" == "FAILED" ]
	then
		ERR_MSG=`$URL_SEND_CMD -XGET http://$CUR_ELASTIC/_snapshot/$REPOSITORY_NAME/$INDEX_NAME?pretty`
		echo "$DATE $INDEX_NAME's snapshot making is fail : $ERR_MSG" >> $LOGFILE
		$URL_SEND_CMD -XDELETE http://$BACKUP_ELASTIC/_snapshot/$REPOSITORY_NAME/$INDEX_NAME
		DATE=`date +"%Y%m%d_%H%M%S"`
		echo "$DATE $INDEX_NAME's snapshot is deleted" >> $LOGFILE
		exit
        fi
        echo "$DATE $INDEX_NAME $STATE"
        sleep 5
done

########## restore snapshut ##########
DATE=`date +"%Y%m%d_%H%M%S"`
echo "$DATE $INDEX_NAME's snapshot restoring is started" >> $LOGFILE

echo "{ \"indices\": \"$INDEX_NAME\", \"index_settings\": { \"index.number_of_replicas\": $BACKUP_ELASTIC_NUM_REPLICA }, \"ignore_index_settings\": [ \"index.refresh_interval\" ] }" > $DATA_FILE
RESULT=`$URL_SEND_CMD -XPOST -H 'Content-Type: application/json' http://$BACKUP_ELASTIC/_snapshot/$REPOSITORY_NAME/$INDEX_NAME/_restore --data-binary @$DATA_FILE`
echo ""
rm -f $DATA_FILE

if [ "$RESULT" != "{\"accepted\":true}" ]
then
	DATE=`date +"%Y%m%d_%H%M%S"`
        echo "$DATE Fail to restore $INDEX_NAME's snapshut : $RESULT" >> $LOGFILE
        exit
fi

########## If you want to set additional configuration, use this part  ##########
echo "{\"index.routing.allocation.total_shards_per_node\" : 8 }" > $DATA_FILE
$URL_SEND_CMD -XPUT -H 'Content-Type: application/json' http://$BACKUP_ELASTIC/$INDEX_NAME/_settings --data-binary @$DATA_FILE
echo ""
rm -f $DATA_FILE

while [ 1 ]
do
        CNT=`$URL_SEND_CMD -s http://$BACKUP_ELASTIC/_cat/shards | grep $INDEX_NAME | grep -v STARTED | wc | cut -c7-8`
        DATE=`date +"%Y%m%d_%H%M%S"`
        echo "$DATE [$INDEX_NAME] CNT : $CNT"
        if [ $CNT -eq 0 ]
        then
                DATE=`date +"%Y%m%d_%H%M%S"`
                echo "$DATE index is opened : $INDEX_NAME" >> $LOGFILE
		########## delete snapshut ##########
                $URL_SEND_CMD -XDELETE http://$BACKUP_ELASTIC/_snapshot/$REPOSITORY_NAME/$INDEX_NAME
                DATE=`date +"%Y%m%d_%H%M%S"`
                echo "$DATE $INDEX_NAME's snapshot is deleted" >> $LOGFILE
                ########## delete source index ##########
		#$URL_SEND_CMD -XDELETE http://$CUR_ELASTIC/$INDEX_NAME
                #DATE=`date +"%Y%m%d_%H%M%S"`
                #echo "$DATE $INDEX_NAME is deleted at Cluster($CUR_ELASTIC)" >> $LOGFILE
                break
        fi
	sleep 10
done

echo "" >> $LOGFILE
echo "------------------------------------------------------------" >> $LOGFILE
echo "$INDEX_NAME Backup and Restore is finished" >> $LOGFILE
date >> $LOGFILE
echo "============================================================" >> $LOGFILE
