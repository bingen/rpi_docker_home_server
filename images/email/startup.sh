#!bin/bash

# set LDAP password from secret
if [ ! -z $LDAP_BIND_PWD_FILE -a -f $LDAP_BIND_PWD_FILE ]; then
    LDAP_BIND_PWD=`cat $LDAP_BIND_PWD_FILE`;
fi

function replace {
    #echo $1
    sed -i "s/\${LDAP_SERVER_HOST}/${LDAP_SERVER_HOST}/g" $1
    sed -i "s/\${LDAP_BIND_DN}/${LDAP_BIND_DN}/g" $1
    sed -i "s/\${LDAP_SEARCH_BASE}/${LDAP_SEARCH_BASE}/g" $1
    sed -i "s/\${DOMAIN}/${DOMAIN}/g" $1
    sed -i "s/\${LDAP_BIND_PWD}/${LDAP_BIND_PWD}/g" $1
}
for i in `find /tmp/config/postfix -type f -exec ls {} \;`; do
    replace $i
done;
for i in `find /tmp/config/dovecot -type f -exec ls {} \;`; do
    replace $i
done;
for i in `find /tmp/config/dovecot/conf.d -type f -exec ls {} \;`; do
    replace $i
done;
for i in `find /tmp/config/saslauth -type f -exec ls {} \;`; do
    replace $i
done;

# Postfix
cp -f /tmp/config/postfix/* /etc/postfix/
mkdir -p /etc/postfix/sasl
cp -f /tmp/config/postfix/sasl/* /etc/postfix/sasl/sasl
echo "${DOMAIN}		OK" >> /etc/postfix/virtual_domains;
for i in ${VIRTUAL_DOMAINS[@]}; do
    echo "$i	OK" >> /etc/postfix/virtual_domains;
done;
postmap hash:/etc/postfix/virtual_domains

# TLS certs
cd /tmp
openssl genrsa -des3 -passout pass:${LDAP_BIND_PWD} -out mail.domain.tld.key 4096
chmod 600 mail.domain.tld.key
openssl req -new -key mail.domain.tld.key -out mail.domain.tld.csr \
        -passin pass:${LDAP_BIND_PWD} \
        -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=www.${DOMAIN}"
openssl x509 -req -days 365 -in mail.domain.tld.csr -signkey mail.domain.tld.key \
        -out mail.domain.tld.crt -passin pass:${LDAP_BIND_PWD}
openssl rsa -in mail.domain.tld.key -out mail.domain.tld.key.nopass \
        -passin pass:${LDAP_BIND_PWD}
mv mail.domain.tld.key.nopass mail.domain.tld.key
openssl req -new -x509 -extensions v3_ca -keyout cakey.pem -out cacert.pem -days 3650 \
        -passout pass:${LDAP_BIND_PWD} \
        -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=www.${DOMAIN}"
chmod 600 mail.domain.tld.key
chmod 600 cakey.pem
mv mail.domain.tld.key /etc/ssl/private/
mv mail.domain.tld.crt /etc/ssl/certs/
mv cakey.pem /etc/ssl/private/
mv cacert.pem /etc/ssl/certs/
# DH
mkdir -p /etc/postfix/certs
cd /etc/postfix/certs
openssl dhparam -2 -out dh_512.pem 512
openssl dhparam -2 -out dh_1024.pem 1024
chown -R root:root /etc/postfix/certs/
chmod -R 600 /etc/postfix/certs/

# Dovecot
mkdir -p /etc/dovecot/private
openssl req -new -x509 -nodes -out /etc/dovecot/dovecot.pem -keyout /etc/dovecot/private/dovecot.pem -days 3650 -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=www.${DOMAIN}"
cp -f /tmp/config/dovecot/* /etc/dovecot/
cp -f /tmp/config/dovecot/conf.d/* /etc/dovecot/conf.d/
#Saslauthd
cp -f /tmp/config/saslauth/saslauthd /etc/default/
cp -f /tmp/config/saslauth/saslauthd.conf /etc/
chown root:sasl /etc/saslauthd.conf
chmod 640 /etc/saslauthd.conf

#rm -Rf /tmp/config

# getmail
# https://stackoverflow.com/a/9625233/1937418
for i in `ls ${MAIL_DATA_PATH}/getmail/getmailrc-*`; do
    (crontab -l 2>/dev/null; echo "*/5  *  *   *   *   sudo -u vmail getmail -r $i --getmaildir ${MAIL_DATA_PATH}/getmail/ >> /dev/null") | crontab - ;
done;
touch ${MAIL_DATA_PATH}/getmail/getmail.log
#chown -R vmail:vmail ${MAIL_DATA_PATH}/getmail

if [ -z "${DATA_CHOWN}" -o "${DATA_CHOWN}" != "0" ]; then
    echo "Changing ownership of Data folder. It may take a while..."
    chown -R vmail:vmail ${MAIL_DATA_PATH}
fi

service rsyslog start
service postfix start
service dovecot start
service saslauthd start
service cron start

tail -fn 0 /var/log/mail.log

tail -f /dev/null

exit 0
