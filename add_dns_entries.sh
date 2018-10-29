#!/bin/bash

STACK_NAME=$1

if [ $# -eq 0 ]; then
    echo "You must pass stack name as a parameter"
    exit 1
fi

echo ""
echo "Adding DNS entries to PI-HOLE"

CONF_FILE=custom_dnsmasq.conf

IP_LOOKUP="$(ip route get 8.8.8.8 | awk '{ print $NF; exit }')"  # May not work for VPN / tun0

# read variables, for domain and host names
source .env

# global domain
echo server=/${LDAP_DOMAIN}/${IP_LOOKUP} > /tmp/${CONF_FILE}
# mail
#echo address=/${MAIL_HOSTNAME}.${LDAP_DOMAIN}/${IP_LOOKUP} > /tmp/${CONF_FILE}
# Nextcloud
#echo address=/${NEXTCLOUD_SERVER_NAME}.${LDAP_DOMAIN}/${IP_LOOKUP} >> /tmp/${CONF_FILE}
# gogs
#echo address=/gogs.${LDAP_DOMAIN}/${IP_LOOKUP} >> /tmp/${CONF_FILE}

# ##### Add entries to PiHole ###### #

host=$(docker stack ps ${STACK_NAME} | grep -v Shutdown | grep Running | grep pihole | awk '{ print $4 }')
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

container=$(ssh $host 'docker ps | grep pihole | cut -f1 -d" "')
#echo Container=$container
if [ -z $container ]; then
    echo "Qué me estás container?!";
    exit 1;
fi

echo Copying user files to Host $host
scp -r /tmp/${CONF_FILE} $host:/tmp/

echo Copying user files to Container $container in Host $host
ssh $host "docker cp /tmp/${CONF_FILE} $container:/etc/dnsmasq.d/99-local-addresses.conf"
# restart dns
ssh $host "docker exec ${container} pihole restartdns"

echo Removing copied user files
ssh $host "docker exec ${container} sh -c 'rm -Rf /tmp/${CONF_FILE}'"
ssh $host "rm -Rf /tmp/${CONF_FILE}"
