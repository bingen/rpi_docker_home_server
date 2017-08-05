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

# Deploy Stack
# seen here: https://github.com/docker/docker/issues/29133#issuecomment-278198683
env $(cat .env | grep "^[A-Z]" | xargs) \
    docker stack deploy --compose-file docker-compose.yml ${STACK_NAME}

echo Wait for services to start
sleep 60

# ##### Add users to LDAP ###### #

host=$(docker stack ps ${STACK_NAME} | grep Running | grep openldap | awk '{ print $4 }')
#echo Host=$host
if [ -z $host ]; then
    echo "No host found!";
    exit 1;
fi
container=$(ssh $host 'docker ps | grep openldap | cut -f1 -d" "')
#echo Container=$container
if [ -z $container ]; then
    echo "Qué me estás container?!";
    exit 1;
fi

# read variables, for mail data path
. .env
# Replace Mail data path for users
find images/rpi-openldap/users -type f -exec \
     sed -i "s/\${MAIL_DATA_PATH}/${MAIL_DATA_PATH//\//\\/}/g" {} \;

echo Copying user files to Host $host
scp -r images/rpi-openldap/users $host:/tmp/

echo Copying user files to Container $container in Host $host
ssh $host "docker cp /tmp/users $container:/tmp/"

echo Adding users to openldap
ssh $host \
    "for i in \$(ls /tmp/users/userimport*.ldif); do \
        ls \$i;
        docker exec ${container} sh -c \
        'slapadd -l '\$i; \
    done;"
#'ldapadd -w \$(cat \${LDAP_ADMIN_PWD_FILE}) -D cn=admin,dc=\${LDAP_ORGANIZATION},dc=\${LDAP_EXTENSION} -f '\$i; \

echo Removing copied user files
ssh $host "docker exec ${container} sh -c 'rm -Rf /tmp/users'"
ssh $host "rm -Rf /tmp/users"
