#!/bin/bash

CFG_FILE=/etc/haproxy/haproxy.cfg
CFG_LE_FILE=/etc/haproxy/haproxy_letsencrypt.cfg
LETSENCRYPT_PORT=8888

mkdir -p /etc/letsencrypt/haproxy

sed -i "s/\${NEXTCLOUD_URL}/${NEXTCLOUD_URL}/g" $CFG_FILE
sed -i "s/\${GOGS_URL}/${GOGS_URL}/g" $CFG_FILE

# Let's Encrypt

# Following these instructions:
# https://serversforhackers.com/c/letsencrypt-with-haproxy

# Start temporary HAProxy
haproxy -f $CFG_LE_FILE -D -p /tmp/haproxy.pid

# Get Let's Encrypt certificates
for _URL in ${NEXTCLOUD_URL} ${GOGS_URL}; do
    if [[ ! -s /etc/letsencrypt/haproxy/${_URL}.pem ]]; then
        # Query Let's Encrypt
        certbot certonly -d ${_URL} \
                --email ${ADMIN_EMAIL} --non-interactive --agree-tos \
                --standalone --http-01-port=${LETSENCRYPT_PORT}
        if [ $? -eq 0 ]; then
            cat /etc/letsencrypt/live/${_URL}/fullchain.pem \
                /etc/letsencrypt/live/${_URL}/privkey.pem \
                > /etc/letsencrypt/haproxy/${_URL}.pem
        fi
    fi
done;

echo Killing haproxy `cat /tmp/haproxy.pid`
kill -SIGTERM `cat /tmp/haproxy.pid`
rm /tmp/haproxy.pid

# Create renew cron job
mv /usr/local/bin/letsencrypt.cron /etc/cron.monthly/letsencrypt
# remove default cron job
mv /etc/cron.d/certbot /tmp

# Start HAProxy
haproxy -f $CFG_FILE
