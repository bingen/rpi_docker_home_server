#!/bin/bash

source /etc/profile.d/gogs.sh

# set DB root password from secret
if [ ! -z $MYSQL_ROOT_PWD_FILE -a -f $MYSQL_ROOT_PWD_FILE ]; then
    MYSQL_ROOT_PWD=`cat $MYSQL_ROOT_PWD_FILE`;
fi

GOGS_DB_PWD=`openssl rand -base64 20`

# set LDAP password from secret
if [ ! -z $LDAP_BIND_PWD_FILE -a -f $LDAP_BIND_PWD_FILE ]; then
    LDAP_BIND_PWD=`cat $LDAP_BIND_PWD_FILE`;
fi

# set Admin password from secret
if [ ! -z $GOGS_ADMIN_PWD_FILE -a -f $GOGS_ADMIN_PWD_FILE ]; then
    GOGS_ADMIN_PWD=`cat $GOGS_ADMIN_PWD_FILE`;
fi

# check needed variables
if [[ -z ${DB_HOST} || -z ${GOGS_DB_NAME} \
            || -z ${GOGS_DB_USER}  || -z ${GOGS_DB_PWD} \
            || -z ${GOGS_ADMIN_PWD} || -z ${ADMIN_EMAIL} \
            || -z ${LDAP_SERVER_HOST} || -z ${LDAP_BIND_DN} \
            || -z ${LDAP_BIND_PWD} || -z ${LDAP_SEARCH_BASE} \
    ]];
then
    echo "Missing variable! You must provide: DB_HOST, GOGS_DB_NAME, \
GOGS_DB_USER, GOGS_DB_PWD, GOGS_ADMIN_PWD, ADMIN_EMAIL and LDAP stuff";
    echo $DB_HOST, $GOGS_DB_NAME, $GOGS_DB_USER, ${#GOGS_DB_PWD}
    echo ${#GOGS_ADMIN_PWD}, ${ADMIN_EMAIL},
    echo ${LDAP_SERVER_HOST}, ${LDAP_BIND_DN}, ${#LDAP_BIND_PWD}, ${LDAP_SEARCH_BASE}
    #env;
    exit 1;
fi

function check_result {
    if [ $1 != 0 ]; then
        echo "Error: $2";
        exit 1;
    fi
}

# ### DB setup ###

# wait for DB to be ready
R=111
while [ $R -eq 111 ]; do
    mysql -u root -p${MYSQL_ROOT_PWD} -h ${DB_HOST} -e "SHOW DATABASES"  2> /dev/null;
    R=$?;
done

# check if DB exists
DB_EXISTS=$(mysql -u root -p${MYSQL_ROOT_PWD} -h ${DB_HOST} -e "SHOW DATABASES" 2> /dev/null | grep ${GOGS_DB_NAME})
echo DB exists: ${DB_EXISTS}

if [ -z "${DB_EXISTS}" ]; then
    echo Creating Database
    #mysql -u root -p${MYSQL_ROOT_PWD} -h ${DB_HOST} -e "DROP DATABASE IF EXISTS ${GOGS_DB_NAME};"
    #check_result $? "Dropping DB"
    mysql -u root -p${MYSQL_ROOT_PWD} -h ${DB_HOST} -e "CREATE DATABASE ${GOGS_DB_NAME};"
    check_result $? "Creating DB"
fi

echo Creating User
# 'IF EXISTS' for DROP USER is available from MariaDB 10.1.3 only
mysql -u root -p${MYSQL_ROOT_PWD} -h ${DB_HOST} -e "DROP USER ${GOGS_DB_USER};" || echo "It seems it didn't exist"
mysql -u root -p${MYSQL_ROOT_PWD} -h ${DB_HOST} -e "CREATE USER ${GOGS_DB_USER} IDENTIFIED BY '${GOGS_DB_PWD}';"
check_result $? "Creating User"
mysql -u root -p${MYSQL_ROOT_PWD} -h ${DB_HOST} -e "GRANT ALL ON ${GOGS_DB_NAME}.* TO ${GOGS_DB_USER};"
check_result $? "Granting permissions"
mysql -u root -p${MYSQL_ROOT_PWD} -h ${DB_HOST} -e "FLUSH PRIVILEGES;"
check_result $? "Flushing privileges"

unset MYSQL_ROOT_PWD

# ### Start ssh server ###

echo "Starting ssh server"
# https://bugs.launchpad.net/ubuntu/+source/openssh/+bug/45234
mkdir -p /var/run/sshd
#/usr/sbin/sshd
service ssh start

# SSH certs
if [[ ! -e ${GOGS_CUSTOM}/https/cert.pem || ! -e ${GOGS_CUSTOM}/https/key.pem ]]; then
    su git -c "mkdir -p ${GOGS_CUSTOM}/https"
    su git -c "cd ${GOGS_CUSTOM}/https && ${GOPATH}/src/github.com/gogits/gogs/gogs cert --ca=true --duration=8760h0m0s --host=${GOGS_DOMAIN} && cd -"
fi

# ### Conf file ###

echo Tweaking config files
CONF_FILE=${GOGS_CUSTOM}/conf/app.ini
# We need to re-generate conf file because we are changing DB pwd
#if [[ ! -e ${CONF_FILE} ]]; then
su git -c "mkdir -p ${GOGS_CUSTOM}/conf"
mv ${GOPATH}/src/github.com/gogits/gogs/custom/conf/app.ini ${CONF_FILE}

echo Setting domain
sed -i "s/GOGS_DOMAIN/${GOGS_DOMAIN}/g" ${CONF_FILE}

# DB conf
echo Setting DB conf
sed -i "s/DB_HOST/${DB_HOST}/g" ${CONF_FILE}
sed -i "s/GOGS_DB_NAME/${GOGS_DB_NAME}/g" ${CONF_FILE}
sed -i "s/GOGS_DB_USER/${GOGS_DB_USER}/g" ${CONF_FILE}
sed -i "s/GOGS_DB_PWD/${GOGS_DB_PWD//\//\\/}/g" ${CONF_FILE}
#fi

# LDAP config
LDAP_FILE=${GOGS_CUSTOM}/conf/auth.d/ldap.conf
#if [[ ! -e ${CONF_FILE} ]]; then
su git -c "mkdir -p ${GOGS_CUSTOM}/conf/auth.d"
mv ${GOPATH}/src/github.com/gogits/gogs/custom/conf/auth.d/ldap.conf ${LDAP_FILE}

echo Setting LDAP conf
sed -i "s/LDAP_SERVER_HOST/${LDAP_SERVER_HOST}/g" ${LDAP_FILE}
sed -i "s/LDAP_BIND_DN/${LDAP_BIND_DN}/g" ${LDAP_FILE}
sed -i "s/LDAP_BIND_PWD/${LDAP_BIND_PWD}/g" ${LDAP_FILE}
sed -i "s/LDAP_SEARCH_BASE/${LDAP_SEARCH_BASE}/g" ${LDAP_FILE}
#fi

# Create admin user if DB was new
if [ -z "${DB_EXISTS}" ]; then
    su -c git "${GOPATH}/src/github.com/gogits/gogs/gogs admin create-user --name admin --password ${GOGS_ADMIN_PWD} --admin --email ${ADMIN_EMAIL}"
fi

#exec "$@"
#exec gosu git ${GOPATH}/src/github.com/gogits/gogs/gogs web
exec su git -c "${GOPATH}/src/github.com/gogits/gogs/gogs web"
