#!/bin/bash

STACK_NAME=$1

if [ $# -eq 0 ]; then
    echo "You must pass stack name as a parameter"
    exit 1
fi

# ##### Add Let's Encrypt certificates ###### #

# Find Nextcloud container
SERVICE=nextcloud
host=$(docker stack ps ${STACK_NAME} | grep Running | grep ${SERVICE} | awk '{ print $4 }')
#echo Host=$host
if [ -z $host ]; then
    echo "No host found!";
    exit 1;
fi
# add avahi suffix
localhostname=$(cat /etc/hostname)
if [ "${localhostname}" != "${host}" ]; then
    host=${host}.local
fi

container=$(ssh $host 'docker ps | grep '${SERVICE}' | cut -f1 -d" "')
#echo Container=$container
if [ -z $container ]; then
    echo "Qué me estás container?!";
    exit 1;
fi

# Run script in container
ssh $host "docker exec ${container} sh -c '/usr/local/bin/letsencrypt.sh'"
