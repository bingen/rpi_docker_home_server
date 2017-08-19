#!/bin/bash

STACK_NAME=$1

if [ $# -eq 0 ]; then
    echo "You must pass stack name as a parameter"
    exit 1
fi

# Delete previous running stack
docker stack rm ${STACK_NAME}

# Build images
docker-compose build
docker push bingen/rpi-openldap
docker push bingen/rpi-mariadb
docker push bingen/rpi-haproxy
docker push bingen/rpi-mailserver
docker push bingen/rpi-nextcloud
docker push bingen/rpi-zoneminder

# Deploy Stack
# seen here: https://github.com/docker/docker/issues/29133#issuecomment-278198683
env $(cat .env | grep "^[A-Z]" | xargs) \
    docker stack deploy --compose-file docker-compose.yml ${STACK_NAME}

echo Wait for services to start
sleep 60

# ##### Add users to LDAP ###### #

./add_users.sh ${STACK_NAME}
