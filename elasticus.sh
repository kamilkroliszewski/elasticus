#!/bin/bash

source /tmp/elasticus_settings
source colors.bash

function banner() {
    clear
    echo -e "${BCyan}"
    cat << "EOF"

_______________             __________                      _____       
___  ____/__  /_____ _________  /___(_)_________  _________ ___(_)_____ 
__  __/  __  /_  __ `/_  ___/  __/_  /_  ___/  / / /_  ___/ __  /_  __ \
_  /___  _  / / /_/ /_(__  )/ /_ _  / / /__ / /_/ /_(__  )___  / / /_/ /
/_____/  /_/  \__,_/ /____/ \__/ /_/  \___/ \__,_/ /____/_(_)_/  \____/  v. 0.1
                                                                        
https://elasticus.io/

EOF
    echo -e "${Color_Off}==================================================="
    echo
    if [[ "$serverHostname" == "" ]]; then serverHostname=none ; fi
    if [[ "$snapshotsRepository" == "" ]]; then snapshotsRepository=none ; fi
    echo -e "${BWhite}Current ElasticSearch Server:${Color_Off} ${UYellow}$serverHostname${Color_Off}"
    echo -e "${BWhite}Current Snapshots Repository:${Color_Off} ${UYellow}$snapshotsRepository${Color_Off}"
    echo
    echo "==================================================="
}

function menu() {
    banner
    echo
    echo -e "${BGreen}    1. ${Color_Off}${BWhite}Set server hostname${Color_Off}"
    echo -e "${BGreen}    2. ${Color_Off}${BWhite}Cluster Management${Color_Off}"
    echo -e "${BGreen}    3. ${Color_Off}${BWhite}Index Management${Color_Off}"
    echo -e "${BGreen}    4. ${Color_Off}${BWhite}Snapshots Management${Color_Off}"
    echo -e "${BGreen}    5. ${Color_Off}${BWhite}Tasks Management${Color_Off}"
    echo
    echo -n "Enter your choice: "
    read -n1 -s choice
    echo 

    if [[ "$choice" == "1" ]]; then setServerHostname ; fi
    if [[ "$choice" == "2" ]]; then if [[ "$serverHostname" != "none" ]]; then clusterAPI ; fi ; fi
    if [[ "$choice" == "3" ]]; then if [[ "$serverHostname" != "none" ]]; then indexAPI ; fi ; fi
    if [[ "$choice" == "4" ]]; then if [[ "$serverHostname" != "none" ]]; then snapshotAPI ; fi ; fi
    if [[ "$choice" == "5" ]]; then if [[ "$serverHostname" != "none" ]]; then taskAPI ; fi ; fi
}

function setServerHostname() {
    echo -n "Enter Elasticsearch address [ex. http://10.0.0.1:9200]: "
    read serverHostname
    echo "serverHostname=$serverHostname" > /tmp/elasticus_settings
    menu
}

function grabUserInput()
{
    echo "" >&2
    echo "Please type/paste in JSON input" >&2
    echo "Press CTRL+D when finished." >&2
    echo "" >&2

    # Read user input until CTRL+D.
    # @see https://stackoverflow.com/a/38811806/430062
    readarray -t user_input

    # Output as a newline-dilemeted string.
    # @see https://stackoverflow.com/a/15692004/430062
    printf '%s\n' "${user_input[@]}"
}

function indexAPI() {
    banner
    echo
    echo -e "${BGreen}    1. ${Color_Off}${BWhite}List indices${Color_Off}"
    echo -e "${BGreen}    2. ${Color_Off}${BWhite}Print index mapping${Color_Off}"
    echo -e "${BGreen}    3. ${Color_Off}${BWhite}Create new index${Color_Off}"
    echo -e "${BGreen}    4. ${Color_Off}${BWhite}Delete index${Color_Off}"
    echo -e "${BGreen}    5. ${Color_Off}${BWhite}Reindex${Color_Off}"
    echo -e "${BGreen}    6. ${Color_Off}${BWhite}List index aliases${Color_Off}"
    echo -e "${BGreen}    7. ${Color_Off}${BWhite}Create index alias${Color_Off}"
    echo ""
    echo -n "Enter your choice: "
    read -n1 -s indexAPI_choice
    echo 

    if [[ "$indexAPI_choice" == "1" ]]; then indexAPI_list ; fi
    if [[ "$indexAPI_choice" == "2" ]]; then indexAPI_getMapping; fi
    if [[ "$indexAPI_choice" == "3" ]]; then indexAPI_create ; fi
    if [[ "$indexAPI_choice" == "4" ]]; then indexAPI_delete ; fi
    if [[ "$indexAPI_choice" == "5" ]]; then indexAPI_reindex ; fi
    if [[ "$indexAPI_choice" == "6" ]]; then indexAPI_alias_list ; fi
    if [[ "$indexAPI_choice" == "7" ]]; then indexAPI_alias_create ; fi
    if [[ "$indexAPI_choice" == "8" ]]; then indexAPI_alias_delete ; fi
}

function indexAPI_list() {
    echo 
    echo "Result:"
    curl -XGET "$serverHostname/_cat/indices?v&s=store.size" 2>/dev/null
    echo
    echo -ne "[ ${BGreen}Search keyword or Ctrl+D to proceed ... ${Color_Off}]: "    
    while read indexAPI_list_grep; do
        echo
        echo "Indices:"
        echo "--------"
        curl -XGET "$serverHostname/_cat/indices?v&s=store.size" 2>/dev/null | grep "$indexAPI_list_grep"
        echo
        echo -ne "[ ${BGreen}Search keyword or Ctrl+D to proceed ... ${Color_Off}]: " 
    done
    menu
}

function indexAPI_getMapping() {
    echo 
    echo -n "Enter index name to print its mapping: "
    read indexAPI_getMapping_indexName
    if [[ "$indexAPI_getMapping_indexName" == "" ]]; then echo "You need to provide index name."; read ; menu ; fi
    echo "Result:"
    curl -XGET "$serverHostname/$indexAPI_getMapping_indexName/_mapping" 2>/dev/null | jq -r .
    echo
    read -p "Press ENTER to continue ..."
    menu
}

function indexAPI_create() {
    echo 
    echo -n "Enter new index name: "
    read indexAPI_create_indexName
    if [[ "$indexAPI_create_indexName" == "" ]]; then echo "You need to provide index name."; read ; menu; fi
    echo -n "Do you want to put your own index mapping? [y/n]: "
    read indexAPI_create_mapping_choice
    if [[ "$indexAPI_create_mapping_choice" == "y" ]]; then
        echo "Put your index settings JSON and end with EOF"
        indexAPI_create_mapping_json=$(grabUserInput)
        echo "$indexAPI_create_mapping_json" > /tmp/elasticus_index_mapping.tmp 
        echo
        curl -X PUT "$serverHostname/$indexAPI_create_indexName" -H 'Content-Type: application/json' -d @/tmp/elasticus_index_mapping.tmp 2>/dev/null | jq -r .
    fi
    echo
    read -p "Press ENTER to continue ..."
    menu
}

function indexAPI_delete() {
    echo
    echo -n "Enter index name to delete: "
    read indexAPI_delete_indexName
    if [[ "$indexAPI_delete_indexName" == "" ]]; then echo "You need to provide index name."; read ; menu; fi
    echo -n "Are you sure you want to delete index ($indexAPI_delete_indexName) ? [y/n]: "
    read indexAPI_delete_choice
    if [[ "$indexAPI_delete_choice" == "y" ]]; then echo; curl -XDELETE "$serverHostname/$indexAPI_delete_indexName" 2>/dev/null | jq -r . ; fi
    echo
    read -p "Press ENTER to continue ..."
    menu
}

function indexAPI_reindex() {
    echo 
    echo -n "Enter source index name: "
    read indexAPI_reindex_sourceIndexName
    echo -n "Enter destination index name: "
    read indexAPI_reindex_destinationIndexName
    echo
curl -X POST "$serverHostname/_reindex?wait_for_completion=false" -H 'Content-Type: application/json' -d'
{
  "source": {
    "index": "'$indexAPI_reindex_sourceIndexName'"
  },
  "dest": {
    "index": "'$indexAPI_reindex_destinationIndexName'"
  }
}
' 2>/dev/null | jq -r .
    echo
    read -p "Press ENTER to continue ..."
    menu
}

function indexAPI_alias_create() {
    echo 
    echo -n "Enter index name for which the alias will be added: "
    read indexAPI_alias_create_indexName
    echo -n "Enter alias name: "
    read indexAPI_alias_create_aliasName
    echo
    curl -X PUT "$serverHostname/$indexAPI_alias_create_indexName/_alias/$indexAPI_alias_create_aliasName" 2>/dev/null | jq -r .
    echo
    read -p "Press ENTER to continue ..."
    menu
}

function indexAPI_alias_delete() {
    echo 
    echo -n "Enter index name to delete alias: "
    read indexAPI_alias_delete_indexName
    echo -n "Enter alias name to delete from $indexAPI_alias_delete_indexName: "
    read indexAPI_alias_delete_aliasName
    echo -n "Are you sure you want to delete index alias ($indexAPI_alias_delete_aliasName) ? [y/n]: "
    read indexAPI_alias_delete_choice
    if [[ "$indexAPI_alias_delete_choice" == "y" ]]; then echo; curl -X DELETE "$serverHostname/$indexAPI_alias_delete_indexName/_alias/$indexAPI_alias_delete_aliasName" 2>/dev/null | jq -r . ; fi
    echo
    read -p "Press ENTER to continue ..."
    menu
}

function indexAPI_alias_list() {
    echo
    curl -X GET "$serverHostname/_cat/aliases?v=true&pretty"
    echo
    read -p "Press ENTER to continue ..."
    menu
}

function clusterAPI() {
    banner
    echo
    echo -e "${BGreen}    1. ${Color_Off}${BWhite}Cluster health${Color_Off}"
    echo -e "${BGreen}    2. ${Color_Off}${BWhite}Show recovery status${Color_Off}"
    echo -e "${BGreen}    3. ${Color_Off}${BWhite}Show nodes disk usage${Color_Off}"
    echo ""
    echo -n "Enter your choice: "
    read -n1 -s clusterAPI_choice
    echo 

    if [[ "$clusterAPI_choice" == "1" ]]; then clusterAPI_health ; fi
    if [[ "$clusterAPI_choice" == "2" ]]; then clusterAPI_recovery ; fi
    if [[ "$clusterAPI_choice" == "3" ]]; then clusterAPI_node_disk_usage ; fi
}

function clusterAPI_health() {
    echo
    clusterAPI_health_json=$(curl -XGET "$serverHostname/_cluster/health" 2>/dev/null)
    cluster_name=$(echo $clusterAPI_health_json | jq -r .cluster_name)
    status=$(echo $clusterAPI_health_json | jq -r .status)
    timed_out=$(echo $clusterAPI_health_json | jq -r .timed_out)
    number_of_nodes=$(echo $clusterAPI_health_json | jq -r .number_of_nodes)
    number_of_data_nodes=$(echo $clusterAPI_health_json | jq -r .number_of_data_nodes)
    active_primary_shards=$(echo $clusterAPI_health_json | jq -r .active_primary_shards)
    active_shards=$(echo $clusterAPI_health_json | jq -r .active_shards)
    relocating_shards=$(echo $clusterAPI_health_json | jq -r .relocating_shards)
    initializing_shards=$(echo $clusterAPI_health_json | jq -r .initializing_shards)
    unassigned_shards=$(echo $clusterAPI_health_json | jq -r .unassigned_shards)
    delayed_unassigned_shards=$(echo $clusterAPI_health_json | jq -r .delayed_unassigned_shards)
    number_of_pending_tasks=$(echo $clusterAPI_health_json | jq -r .number_of_pending_tasks)
    number_of_in_flight_fetch=$(echo $clusterAPI_health_json | jq -r .number_of_in_flight_fetch)
    task_max_waiting_in_queue_millis=$(echo $clusterAPI_health_json | jq -r .task_max_waiting_in_queue_millis)
    active_shards_percent_as_number=$(echo $clusterAPI_health_json | jq -r .active_shards_percent_as_number)

    if [[ "$status" == "green" ]]; then echo -e "${BWhite}Cluster name           : ${IGreen}$cluster_name"; fi
    if [[ "$status" == "yellow" ]]; then echo -e "${BWhite}Cluster name           : ${IYellow}$cluster_name"; fi
    if [[ "$status" == "red" ]]; then echo -e "${BWhite}Cluster name           : ${IRed}$cluster_name"; fi

    echo -e "${BWhite}Number of nodes        : ${Color_Off}$number_of_nodes"
    echo -e "${BWhite}Number of data nodes   : ${Color_Off}$number_of_data_nodes"
    echo -e "${BWhite}Active shards          : ${Color_Off}$active_shards_percent_as_number % - (shards count: $active_shards , primary shards count: $active_primary_shards)"
    echo -e "${BWhite}Relocating shards      : ${Color_Off}$relocating_shards"
    echo -e "${BWhite}Initializing shards    : ${Color_Off}$initializing_shards"
    echo -e "${BWhite}Unassigned shards      : ${Color_Off}$unassigned_shards"
    echo -e "${BWhite}Pending tasks          : ${Color_Off}$number_of_pending_tasks"
    echo -e "${BWhite}Task max wait in queue : ${Color_Off}$task_max_waiting_in_queue_millis ms"
    echo -e "${Color_Off}"
    read -p "Press ENTER to continue ..."
    menu
}

function clusterAPI_recovery() {
    echo 
    echo "Result:"
    echo "-------"
    watch -n1 'curl -XGET "'$serverHostname'/_cat/recovery?v&active_only=true" 2>/dev/null'
    echo 
    read -p "Press ENTER to continue ..."
    menu
}

function clusterAPI_node_disk_usage() {
    echo
    clusterAPI_node_disk_usage_call=$(curl -XGET "$serverHostname/_cat/allocation" 2>/dev/null | sort -k9)
        while IFS= read -r clusterAPI_node_disk_usage_result ; do 
            result_shards=$(echo $clusterAPI_node_disk_usage_result | awk '{print $1}')
            result_disk_indices=$(echo $clusterAPI_node_disk_usage_result | awk '{print $2}')
            result_disk_used=$(echo $clusterAPI_node_disk_usage_result | awk '{print $3}')
            result_disk_avail=$(echo $clusterAPI_node_disk_usage_result | awk '{print $4}')
            result_disk_total=$(echo $clusterAPI_node_disk_usage_result | awk '{print $5}')
            result_disk_percent=$(echo $clusterAPI_node_disk_usage_result | awk '{print $6}')
            result_host=$(echo $clusterAPI_node_disk_usage_result | awk '{print $7}')
            result_ip=$(echo $clusterAPI_node_disk_usage_result | awk '{print $8}')
            result_node=$(echo $clusterAPI_node_disk_usage_result | awk '{print $9}')

            echo -e "${BWhite}Node         : ${IGreen}$result_node"
            echo -e "${BWhite}Host         : ${ICyan}$result_host ($result_ip)"
            echo -e "${BWhite}Disk         : ${IYellow}$result_disk_percent % ( used $result_disk_used of $result_disk_total , $result_disk_avail available"
            echo -e "${BWhite}Indices Size : ${IBlue}$result_disk_indices"
            echo -e "${Color_Off}"
        done <<< "$clusterAPI_node_disk_usage_call"
    read -p "Press ENTER to continue ..."
    menu
}

function taskAPI() {
    banner
    echo
    echo -e "${BGreen}    1. ${Color_Off}${BWhite}List active tasks${Color_Off}"
    echo -e "${BGreen}    2. ${Color_Off}${BWhite}Get detailed task information${Color_Off}"
    echo -e "${BGreen}    3. ${Color_Off}${BWhite}Current Reindexing tasks information${Color_Off}"
    echo ""
    echo -n "Enter your choice: "
    read -n1 -s taskAPI_choice
    echo 

    if [[ "$taskAPI_choice" == "1" ]]; then taskAPI_list ; fi
    if [[ "$taskAPI_choice" == "2" ]]; then taskAPI_details ; fi
    if [[ "$taskAPI_choice" == "3" ]]; then taskAPI_reindex_tasks ; fi
}

function taskAPI_list() {
    echo 
    echo "Result:"
    echo "-------"
    curl -XGET "$serverHostname/_cat/tasks?v&pretty" 2>/dev/null | tail -n +2 | column -t -N "action,task_id,parent_task_id,type,start_time,timestamp,running_time,ip,node" --tree-id task_id --tree-parent parent_task_id --tree task_id
    echo 
    read -p "Press ENTER to continue ..."
    menu
}

function taskAPI_details() {
    echo 
    echo -n "Enter task_id to get its details: "
    read taskAPI_task_id
    echo "Result:"
    echo "-------"
    curl -XGET "$serverHostname/_tasks/$taskAPI_task_id" 2>/dev/null | jq -r .
    echo 
    read -p "Press ENTER to continue ..."
    menu
}

function taskAPI_reindex_tasks() {
    echo
    taskAPI_reindex_tasks_loop=$(curl -XGET "$serverHostname/_cat/tasks?v&pretty" 2>/dev/null | grep "reindex" | awk '{print $2}')
    for taskAPI_reindex_task_id in $taskAPI_reindex_tasks_loop ; do
        task_json=$(curl -XGET "$serverHostname/_tasks/$taskAPI_reindex_task_id" 2>/dev/null)
        task_completed=$(echo $task_json | jq -r .completed)
        task_description=$(echo $task_json | jq -r .task.description)
        task_status_total=$(echo $task_json | jq -r .task.status.total)
        task_status_created=$(echo $task_json | jq -r .task.status.created)
        
        let "task_status_percent_let = $task_status_created * 100 / $task_status_total"
        task_status_percent=$(echo "$task_status_percent_let %")

        echo "$task_description - [ $task_status_percent completed ]"
        echo
    done
    echo
    read -p "Press ENTER to continue ..."
    menu
}

menu
