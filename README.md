# elasticsearch-operation-utils

# Auto Backup Script : elastic_index_backup.sh

description of flow 
1. make snapshut from indexing cluster
2. wait until making snapshut will be done
3. restore snapshut at backup cluster
4. set configuration of index at backup cluster
5. wait until restoring snapshut will be done
6. delete snapshut
