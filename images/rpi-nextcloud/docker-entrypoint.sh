#!/bin/bash

#set -e

#NEXTCLOUD_DB_PWD=`< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-32};echo;`
NEXTCLOUD_DB_PWD=`openssl rand -base64 20`

if [ -z "${NEXTCLOUD_SERVER_NAME}" ]; then
    echo >&2 'error: you have to provide a server-name (NEXTCLOUD_SERVER_NAME)'
    exit 1
fi

sudo sed -i "s/server_name localhost/server_name ${NEXTCLOUD_SERVER_NAME}.${NEXTCLOUD_DOMAIN} ${NEXTCLOUD_SERVER_NAME}/g" /etc/nginx/sites-available/default

# set Admin password from secret
if [ ! -z $NEXTCLOUD_ADMIN_PWD_FILE -a -f $NEXTCLOUD_ADMIN_PWD_FILE ]; then
    NEXTCLOUD_ADMIN_PWD=`cat $NEXTCLOUD_ADMIN_PWD_FILE`;
fi
# set LDAP password from secret
if [ ! -z $LDAP_BIND_PWD_FILE -a -f $LDAP_BIND_PWD_FILE ]; then
    LDAP_BIND_PWD=`cat $LDAP_BIND_PWD_FILE`;
fi
# set DB root password from secret
if [ ! -z $MYSQL_ROOT_PWD_FILE -a -f $MYSQL_ROOT_PWD_FILE ]; then
    MYSQL_ROOT_PWD=`cat $MYSQL_ROOT_PWD_FILE`;
fi
# set password salt from secret
if [ ! -z $NEXTCLOUD_SALT_FILE -a -f $NEXTCLOUD_SALT_FILE ]; then
    NEXTCLOUD_SALT=`cat $NEXTCLOUD_SALT_FILE`;
fi
# set NC secret from secret
if [ ! -z $NEXTCLOUD_SECRET_FILE -a -f $NEXTCLOUD_SECRET_FILE ]; then
    NEXTCLOUD_SECRET=`cat $NEXTCLOUD_SECRET_FILE`;
fi

# check needed variables
if [[ -z ${DB_HOST} || -z ${NEXTCLOUD_DB_NAME} || -z ${NEXTCLOUD_DB_USER} \
            || -z ${NEXTCLOUD_DB_PWD} || -z ${NEXTCLOUD_ADMIN_PWD} \
            || -z ${NEXTCLOUD_DATA_PATH} || -z ${NEXTCLOUD_BACKUP_PATH} ]]; then
    echo "Missing variable! You must provide: DB_HOST, NEXTCLOUD_DB_NAME, \
NEXTCLOUD_DB_USER, NEXTCLOUD_DB_PWD, NEXTCLOUD_ADMIN_PWD, NEXTCLOUD_DATA_PATH, \
NEXTCLOUD_BACKUP_PATH";
    #env;
    exit 1;
fi

# SSL certificates
if [ ! -f /etc/nginx/ssl/nextcloud.crt ]; then
    sudo mkdir /etc/nginx/ssl
    sudo openssl genrsa -out /etc/nginx/ssl/nextcloud.key 4096
    sudo openssl req -new -sha256 -batch -subj "/CN=$NEXTCLOUD_SERVER_NAME" -key /etc/nginx/ssl/nextcloud.key -out /etc/nginx/ssl/nextcloud.csr
    sudo openssl x509 -req -sha256 -days 3650 -in /etc/nginx/ssl/nextcloud.csr -signkey /etc/nginx/ssl/nextcloud.key -out /etc/nginx/ssl/nextcloud.crt
fi

# Data folder
if [ -z "${DATA_CHOWN}" -o "${DATA_CHOWN}" != "0" ]; then
    echo "Changing ownership of Data folder. It may take a while..."
    chown -R www-data:www-data ${NEXTCLOUD_DATA_PATH};
fi

function check_result {
    if [ $1 != 0 ]; then
        echo "Error: $2";
        exit 1;
    fi
}
# ### DB ###

# wait for DB to be ready
R=111
while [ $R -eq 111 ]; do
    mysql -u root -p${MYSQL_ROOT_PWD} -h ${DB_HOST} -e "SHOW DATABASES"  2> /dev/null;
    R=$?;
done

# check if DB exists
DB_EXISTS=$(mysql -u root -p${MYSQL_ROOT_PWD} -h ${DB_HOST} -e "SHOW DATABASES" 2> /dev/null | grep ${NEXTCLOUD_DB_NAME})
echo DB exists: ${DB_EXISTS}

if [ -z "${DB_EXISTS}" ]; then
    echo Creating Database
    #mysql -u root -p${MYSQL_ROOT_PWD} -h ${DB_HOST} -e "DROP DATABASE IF EXISTS ${NEXTCLOUD_DB_NAME};"
    #check_result $? "Dropping DB"
    mysql -u root -p${MYSQL_ROOT_PWD} -h ${DB_HOST} -e "CREATE DATABASE ${NEXTCLOUD_DB_NAME};"
    check_result $? "Creating DB"
fi

echo Creating User
# 'IF EXISTS' for DROP USER is available from MariaDB 10.1.3 only
mysql -u root -p${MYSQL_ROOT_PWD} -h ${DB_HOST} -e "DROP USER ${NEXTCLOUD_DB_USER};" || echo "It seems it didn't exist"
mysql -u root -p${MYSQL_ROOT_PWD} -h ${DB_HOST} -e "CREATE USER ${NEXTCLOUD_DB_USER} IDENTIFIED BY '${NEXTCLOUD_DB_PWD}';"
check_result $? "Creating User"
mysql -u root -p${MYSQL_ROOT_PWD} -h ${DB_HOST} -e "GRANT ALL ON ${NEXTCLOUD_DB_NAME}.* TO ${NEXTCLOUD_DB_USER};"
check_result $? "Granting permissions"
mysql -u root -p${MYSQL_ROOT_PWD} -h ${DB_HOST} -e "FLUSH PRIVILEGES;"
check_result $? "Flushing privileges"

unset MYSQL_ROOT_PWD

# DB Backup
if [ ! -z "${DB_EXISTS}" -a ! -z "${NEXTCLOUD_DB_BACKUP}" -a -f "${NEXTCLOUD_DB_BACKUP}" ]; then
    echo Restoring DB Backup...
    mysql -u ${NEXTCLOUD_DB_USER} -p${NEXTCLOUD_DB_PWD} -D ${NEXTCLOUD_DB_NAME} -h ${DB_HOST} < ${NEXTCLOUD_DB_BACKUP};
    check_result $? "Restoring DB"
fi
# empty oc_users table
echo "Removing users"
mysql -u ${NEXTCLOUD_DB_USER} -p${NEXTCLOUD_DB_PWD} -D ${NEXTCLOUD_DB_NAME} -h ${DB_HOST} -e "TRUNCATE TABLE oc_users;";
check_result $? "Truncating Users table"
mysql -u ${NEXTCLOUD_DB_USER} -p${NEXTCLOUD_DB_PWD} -D ${NEXTCLOUD_DB_NAME} -h ${DB_HOST} -e "TRUNCATE TABLE oc_ldap_user_mapping;";
check_result $? "Truncating LDAP Users mapping table"

# ### Nextcloud config file ###

echo "Configuring Nextcloud"
cd /var/www/nextcloud
sudo -u www-data php occ maintenance:install --database "mysql" --database-host ${DB_HOST} --database-name ${NEXTCLOUD_DB_NAME}  --database-user ${NEXTCLOUD_DB_USER} --database-pass ${NEXTCLOUD_DB_PWD} --admin-user "admin" --admin-pass ${NEXTCLOUD_ADMIN_PWD} --data-dir ${NEXTCLOUD_DATA_PATH}
check_result $? "Initializing Config"
# Password salt and secret are used by Passman and must remain the same after
# restarting of the instance, otherwise vaults would become inaccessible
if [ ! -z "${NEXTCLOUD_SALT}" ]; then
    sudo -u www-data php occ config:system:set passwordsalt --value "${NEXTCLOUD_SALT}"
fi
if [ ! -z "${NEXTCLOUD_SECRET}" ]; then
    sudo -u www-data php occ config:system:set secret --value "${NEXTCLOUD_SECRET}"
fi
sudo -u www-data php occ config:system:set trusted_domains 0 --value ${NEXTCLOUD_SERVER_NAME}.${NEXTCLOUD_DOMAIN}
sudo -u www-data php occ config:system:set trusted_domains 1 --value ${NEXTCLOUD_DOMAIN}
# Already in manitenance:install command:
#sudo -u www-data php occ config:system:set datadirectory ${NEXTCLOUD_DATA_PATH}
#sudo -u www-data php occ config:system:set dbtype --value mysql
#sudo -u www-data php occ config:system:set dbhost --value ${DB_HOST}
#sudo -u www-data php occ config:system:set dbname --value ${NEXTCLOUD_DB_NAME}
#sudo -u www-data php occ config:system:set dbuser --value ${NEXTCLOUD_DB_USER}
#sudo -u www-data php occ config:system:set dbpassword --value ${NEXTCLOUD_DB_PWD}
sudo -u www-data php occ config:system:set mail_from_address --value postmaster
sudo -u www-data php occ config:system:set mail_domain --value ${NEXTCLOUD_DOMAIN}
sudo -u www-data php occ config:system:set ldapIgnoreNamingRules --value false
sudo -u www-data php occ config:system:set ldapProviderFactory --value "\\OCA\\User_LDAP\\LDAPProviderFactory"
# https://docs.nextcloud.com/server/13/admin_manual/configuration_server/caching_configuration.html
sudo -u www-data php occ config:system:set memcache.local --value '\OC\Memcache\APCu'
sudo -u www-data php occ config:app:set user_ldap enabled --value yes
sudo -u www-data php occ config:app:set user_ldap types --value authentication
sudo -u www-data php occ config:app:set user_ldap ldap_host --value ${LDAP_SERVER_HOST}
sudo -u www-data php occ config:app:set user_ldap ldap_port --value 389
sudo -u www-data php occ config:app:set user_ldap ldap_base --value ${LDAP_SEARCH_BASE}
sudo -u www-data php occ config:app:set user_ldap ldap_base_users --value ${LDAP_SEARCH_BASE}
sudo -u www-data php occ config:app:set user_ldap ldap_base_groups --value ${LDAP_SEARCH_BASE}
sudo -u www-data php occ config:app:set user_ldap ldap_dn --value ${LDAP_BIND_DN}
sudo -u www-data php occ config:app:set user_ldap ldap_agent_password --value `printf "${LDAP_BIND_PWD}" | base64`
sudo -u www-data php occ config:app:set user_ldap ldap_email_attr --value mail
sudo -u www-data php occ config:app:set user_ldap ldap_login_filter --value "(&(objectclass=*)(|(uniqueIdentifier=%uid)(mail=%uid)))"
sudo -u www-data php occ config:app:set user_ldap ldap_login_filter_mode --value 1
sudo -u www-data php occ config:app:set user_ldap ldap_loginfilter_email --value 1
sudo -u www-data php occ config:app:set user_ldap ldap_loginfilter_username --value 1
sudo -u www-data php occ config:app:set user_ldap ldap_user_filter_mode --value 1
sudo -u www-data php occ config:app:set user_ldap ldap_userlist_filter --value "(objectclass=*)"
sudo -u www-data php occ config:app:set user_ldap use_memberof_to_detect_membership --value 1
sudo -u www-data php occ config:app:set user_ldap ldap_display_name --value "cn"
#sudo -u www-data php occ config:app:set user_ldap ldap_expert_username_attr --value "mail"

sudo -u www-data php occ config:app:set user_ldap has_memberof_filter_support --value "0"
sudo -u www-data php occ config:app:set user_ldap home_folder_naming_rule --value ""
sudo -u www-data php occ config:app:set user_ldap last_jpegPhoto_lookup --value "0"
sudo -u www-data php occ config:app:set user_ldap ldap_attributes_for_group_search --value ""
sudo -u www-data php occ config:app:set user_ldap ldap_attributes_for_user_search --value ""
sudo -u www-data php occ config:app:set user_ldap ldap_backup_host --value ""
sudo -u www-data php occ config:app:set user_ldap ldap_backup_port --value ""
sudo -u www-data php occ config:app:set user_ldap ldap_cache_ttl --value "600"
sudo -u www-data php occ config:app:set user_ldap ldap_configuration_active --value "1"
sudo -u www-data php occ config:app:set user_ldap ldap_dynamic_group_member_url --value ""
sudo -u www-data php occ config:app:set user_ldap ldap_experienced_admin --value "0"
sudo -u www-data php occ config:app:set user_ldap ldap_expert_uuid_group_attr --value ""
sudo -u www-data php occ config:app:set user_ldap ldap_expert_uuid_user_attr --value ""
sudo -u www-data php occ config:app:set user_ldap ldap_group_display_name --value "cn"
sudo -u www-data php occ config:app:set user_ldap ldap_group_filter --value ""
sudo -u www-data php occ config:app:set user_ldap ldap_group_filter_mode --value "0"
sudo -u www-data php occ config:app:set user_ldap ldap_group_member_assoc_attribute --value "uniqueMember"
sudo -u www-data php occ config:app:set user_ldap ldap_groupfilter_groups --value ""
sudo -u www-data php occ config:app:set user_ldap ldap_groupfilter_objectclass --value ""
sudo -u www-data php occ config:app:set user_ldap ldap_loginfilter_attributes --value ""
sudo -u www-data php occ config:app:set user_ldap ldap_nested_groups --value "0"
sudo -u www-data php occ config:app:set user_ldap ldap_override_main_server --value ""
sudo -u www-data php occ config:app:set user_ldap ldap_paging_size --value "500"
sudo -u www-data php occ config:app:set user_ldap ldap_quota_attr --value ""
sudo -u www-data php occ config:app:set user_ldap ldap_quota_def --value ""
sudo -u www-data php occ config:app:set user_ldap ldap_tls --value "0"
sudo -u www-data php occ config:app:set user_ldap ldap_turn_off_cert_check --value "0"
sudo -u www-data php occ config:app:set user_ldap ldap_turn_on_pwd_change --value "0"
sudo -u www-data php occ config:app:set user_ldap ldap_user_display_name_2 --value ""
sudo -u www-data php occ config:app:set user_ldap ldap_userfilter_groups --value ""
sudo -u www-data php occ config:app:set user_ldap ldap_userfilter_objectclass --value ""

# upgrade apps
sudo -u www-data php occ upgrade

# enable apps
sudo -u www-data php occ app:enable contacts
sudo -u www-data php occ app:enable calendar
sudo -u www-data php occ app:enable tasks
#sudo -u www-data php occ app:enable spreed
sudo -u www-data php occ app:enable bookmarks
#sudo -u www-data php occ app:enable direct_menu
sudo -u www-data php occ app:enable mail
sudo -u www-data php occ app:enable news
sudo -u www-data php occ app:enable notes
sudo -u www-data php occ app:enable passman
sudo -u www-data php occ app:enable tasks
sudo -u www-data php occ app:enable drawio
sudo -u www-data php occ app:enable gpxedit
sudo -u www-data php occ app:enable gpxmotion
sudo -u www-data php occ app:enable gpxpod
sudo -u www-data php occ app:enable sharebyemail
sudo -u www-data php occ app:enable socialsharing_email

# copy variables to a file for cron
printenv | grep "NEXTCLOUD\|DB" | sed 's/^\(.*\)$/export \1/g' > /root/env.sh

service cron start

exec "$@"
