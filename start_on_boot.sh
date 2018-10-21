#!/bin/bash

STACK_NAME=$1

echo "Processing stack ${STACK_NAME} on reboot"

if [ ! $# -eq 1 ]; then
    echo "Usage $0 <stack_name>";
    exit 1;
fi

# Script to be run on boot, on crontab
# makes sure that all swarm nodes are ready, so services are split

start_stack() {
    echo "Starting stack ${STACK_NAME}"
    cd ~/docker_home_server
    env $(cat .env | grep "^[A-Z]" | xargs)  docker stack deploy --compose-file docker-compose.yml ${STACK_NAME}
}

stop_stack() {
    echo "Stopping stack ${STACK_NAME}"
    docker stack rm ${STACK_NAME}
    sleep 10
    docker network ls | grep ${STACK_NAME}_default
    if [ $? -gt 0 ]; then
        for i in `docker network inspect ${STACK_NAME}_default | grep Name | grep ${STACK_NAME}_ | grep -v ${STACK_NAME}_default | cut -d':' -f2 | cut -d'"' -f 2`; do
            echo "Disconnectiong endpoint $i from network ${STACK_NAME}_default";
            docker network disconnect -f ${STACK_NAME}_default $i;
        done;
    fi
    sleep 10
}

# is it running?
docker stack ls | grep ${STACK_NAME}
if [ $? -gt 0 ]; then
    start_stack
fi

# check workers are up
TMP_FILE="/tmp/pending_nodes.txt"
echo "Checking workers"
for i in $(seq 1 5); do
    echo "Attempt 1";
    docker node ls --filter role=worker --format "{{.Hostname}} {{.Status}} {{.Availability}}"  | grep -v "Ready Active" | tee ${TMP_FILE};
    PENDING=`cat ${TMP_FILE} | wc -l`
    echo "Pending: ${PENDING}"
    if [ $PENDING -eq 0 ]; then
        break
    fi
    sleep 30
done

# check workers have volumes mounted
echo "Checking workers mounted volumes"
echo `docker node ls --filter role=worker --format "{{.Hostname}} {{.Status}} {{.Availability}}" | grep "Ready Active" | cut -f 1 -d ' '`
for node in `docker node ls --filter role=worker --format "{{.Hostname}} {{.Status}} {{.Availability}}" | grep "Ready Active"  | cut -f 1 -d ' '`; do
    echo "Checking volumes on $node"
    ssh ${node}.local "mount | grep volumes || mount /media/volumes"
done

# restart stack
stop_stack
start_stack

# wait for OpenLDAP
sleep 120
# add users
# in case it's not ready yet, try 5 times
for i in $(seq 1 5); do
    echo "Adding users - Attempt $i";
    ./add_users.sh ${STACK_NAME};
    if [ $? -eq 0 ]; then
        break;
    fi
    sleep 30
done
