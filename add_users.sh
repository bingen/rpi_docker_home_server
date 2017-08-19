#!/bin/bash

STACK_NAME=$1

if [ $# -eq 0 ]; then
    echo "You must pass stack name as a parameter"
    exit 1
fi

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
