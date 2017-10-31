# elasticsearch-operation-utils

# Auto Backup Script : elastic_index_backup.sh

description of flow 
1. make shapshut from indexing cluster
2. wait until making snapshut will be done
3. restore shapshut at backup cluster
4. set configuration of index at backup cluster
5. wait until restoring shapshut will be done
6. delete shapshut
