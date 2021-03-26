#!/bin/bash

if [ "$1" == "" ] || [ "$2" == "" ]; then
  echo "Usage: ./reindex.sh [REMOTE_HOST_Sumber:REMOTE_PORT] [INDEX_PATTERN_sumber] [LOCAL_HOST_Baru:LOCAL_PORT]"
  exit 1
fi

REMOTE_HOST=$1
PATTERN=$2
if [ "$3" == "" ]; then
  LOCAL_HOST="localhost:9200"
else
  LOCAL_HOST=$3
fi

echo "---------------------------- NOTICE ----------------------------------"
echo "You must ensur you have the following setting in your local ES host's:"
echo "elasticsearch.yml config (the one re-indexing to):"
echo "    reindex.remote.whitelist: $REMOTE_HOST"
echo "Also, if an index template is necessary for this data, you must create"
echo "locally before you start the re-indexing process"
echo "----------------------------------------------------------------------"
sleep 3

INDICES=$(curl -u elastic:P@ssw0rd -k --silent "https://$REMOTE_HOST/_cat/indices/$PATTERN?h=index")
TOTAL_INCOMPLETE_INDICES=0
TOTAL_INDICES=0
TOTAL_DURATION=0
INCOMPLETE_INDICES=()
echo "---------------------------- list Index ----------------------------------"
echo "$INDICES"
echo "----------------------------------------------------------------------"

for INDEX in $INDICES; do
	p_index_n=${#INDEX}
	p_index_n=$((p_index_n+5))
	
	echo "index_source : $INDEX"
	index_map=$(curl -u elastic:P@ssw0rd -k --silent "https://$REMOTE_HOST/$INDEX/_mapping")
	p_map_n=${#index_map}
	p_map_n=$((p_map_n-2-p_index_n))
	maps=${index_map:p_index_n:p_map_n}
	#maps=${maps//'"'/'\"'}
	
	index_set=$(curl -u elastic:P@ssw0rd -k --silent "https://$REMOTE_HOST/$INDEX/_settings/index.mapping*")
	p_set_n=${#index_set}
	p_set_n=$((p_set_n-2-p_index_n))
	sets=${index_set:p_index_n:p_set_n}
	#sets=${sets//'"'/'\"'}
	
	c_body="{$sets , $maps}"
	
	echo $c_body > ujimaps.txt
	
	TOTAL_DOCS_REMOTE=$(curl -u elastic:P@ssw0rd --silent -k "https://$REMOTE_HOST/_cat/indices/$INDEX?h=docs.count")
	echo "Attempting to re-indexing $INDEX ($TOTAL_DOCS_REMOTE docs total $LOCAL_HOST) from remote ES server..."
	SECONDS=0
	curl -u ece-admin:P@ssw0rd --insecure -HContent-Type:application/json -X PUT "https://$LOCAL_HOST/$INDEX" -d @ujimaps.txt
	
	sleep 2
done
#curl -X GET "localhost:9200/my-index-000001,my-index-000002/_mapping?pretty"
#./reindex.sh 10.8.150.159:9200 metricbeat-* 30dd82c52f0f4953a4ee11ba7f2de43e.10.8.150.222.ip.es.io:9243


echo "---------------------- STATS --------------------------"
echo "Total Duration of Re-Indexing Process: $((TOTAL_DURATION / 60))m $((TOTAL_DURATION % 60))"
echo "Total Indices: $TOTAL_INDICES"
echo "Total Incomplete Re-Indexed Indices: $TOTAL_INCOMPLETE_INDICES"
if [ "$TOTAL_INCOMPLETE_INDICES" -ne "0" ]; then
  printf '%s\n' "${INCOMPLETE_INDICES[@]}"
fi
echo "-------------------------------------------------------"
echo ""
