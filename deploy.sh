#!/bin/bash

STACK_NAME=$1
BUILD=$2
if [ -z $BUILD ]; then
    BUILD=1;
fi
if [ $# -eq 0 ]; then
    echo "You must pass stack name as a parameter"
    exit 1
fi

# Delete previous running stack
docker stack rm ${STACK_NAME}

# Build images
if [ $BUILD -eq 1 ]; then
    docker-compose build
    docker push bingen/rpi-openldap
    docker push bingen/rpi-mariadb
    docker push bingen/rpi-haproxy
    docker push bingen/rpi-mailserver
    docker push bingen/rpi-nextcloud
    docker push bingen/rpi-zoneminder
fi

# Deploy Stack
# seen here: https://github.com/docker/docker/issues/29133#issuecomment-278198683
env $(cat .env | grep "^[A-Z]" | xargs) \
    docker stack deploy --compose-file docker-compose.yml ${STACK_NAME}

echo Wait for services to start
sleep 60

# ##### Add users to LDAP ###### #

./add_users.sh ${STACK_NAME}

# Add local domains
./add_dns_entries.sh ${STACK_NAME}

# Wait for Nextcloud
NC_UP=0
while [ $NC_UP -eq 0 ]; do
    # TODO: Use docker inspect Go templates
    #NC_IP=$(docker network inspect debuen_default | grep -A 3 nextcloud | grep IPv4Address | cut -d':' -f 2 | cut -d'"' -f 2 | cut -d'/' -f 1)
    # Find Nextcloud container
    SERVICE=nextcloud
    host=$(docker stack ps ${STACK_NAME} | grep Running | grep ${SERVICE} | awk '{ print $4 }')
    #echo Host=$host
    if [ -z $host ]; then
        echo "No host found!";
        continue;
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
        continue;
    fi
    #NC_IP=$(ssh $host "docker exec ${container} sh -c 'ifconfig eth1' | grep 'inet ' | cut -d':' -f 2 | cut -d' ' -f 1")
    curl http://${host}/index.nginx-debian.html 2>/dev/null | grep title | grep Welcome 1>/dev/null;
    NC_UP=$((1 - $?));
done;

./letsencrypt.sh ${STACK_NAME}
