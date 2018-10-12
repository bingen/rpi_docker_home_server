#!/bin/sh

# read environment variables
. /root/env.sh

LOG_PATH=/tmp
ERROR=""
TIMESTAMP=`date +"%Y%m%d"`

# TODO: mail
#Mail vars
#MAIL_FROM="postmaster@{DOMAIN}"
#MAIL_TO=
#MAIL_SUBJECT='Nextcloud backup report'

mail() {
    #mutt -e "set from=${MAIL_FROM}" -s "${MAIL_SUBJECT}" -- "${MAIL_TO}" <<< $1
    echo $1
}

# Backup config file (it's important for salt and secret)
echo "Copying config file"
cp /var/www/nextcloud/config/config.php ${NEXTCLOUD_BACKUP_PATH}/config_${TIMESTAMP}.php
if [ $? != 0 ]
then
    tmp="Error copying config file.\n"
    echo $tmp
    ERROR="$ERROR $tmp"
fi

# Backup Mysql DB
DB_PWD=`grep dbpassword /var/www/nextcloud/config/config.php | awk -F "'" '{ print $4 }'`
DB_BACKUP_FILE=${NEXTCLOUD_BACKUP_PATH}/nextcloud-sqlbkp_${TIMESTAMP}.sql
mysqldump --lock-tables -u ${NEXTCLOUD_DB_USER} -p${DB_PWD} -h ${DB_HOST} ${NEXTCLOUD_DB_NAME} > ${DB_BACKUP_FILE}
if [ $? != 0 ]
then
    tmp="Error backing Nextcloud DB up\n"
    echo $tmp
    ERROR="$ERROR $tmp"
fi
# Compress Mysql Backup
gzip ${DB_BACKUP_FILE}
# Remove backups older than 5 days
find ${NEXTCLOUD_BACKUP_PATH} -maxdepth 1 -mtime +5 -type f -name "nextcloud-sqlbkp*" -delete
find ${NEXTCLOUD_BACKUP_PATH} -maxdepth 1 -mtime +5 -type f -name "config_*\.php" -delete
# Remove old logs too
find ${LOG_PATH} -mtime +5 -type f -name "backup_nextcloud*" -delete

# Backup Nextcloud root folder
echo "Copying Nextcloud"
rsync -auv --delete --ignore-errors /var/www/nextcloud/  ${NEXTCLOUD_BACKUP_PATH}/nextcloud > ${LOG_PATH}/backup_nextcloud-${TIMESTAMP}.log 2>&1
if [ $? != 0 ]
then
    tmp="Error copying Nextcloud.\n"
    echo $tmp
    ERROR="$ERROR $tmp"
fi

# Backup Nextcloud Data folder
echo "Copying Data"
rsync -auv --delete --ignore-errors ${NEXTCLOUD_DATA_PATH}/  ${NEXTCLOUD_BACKUP_PATH}/data > ${LOG_PATH}/backup_nextcloud_data-${TIMESTAMP}.log 2>&1
if [ $? != 0 ]
then
    tmp="Error copying Data.\n"
    echo $tmp
    ERROR="$ERROR $tmp"
fi


if [ -z "$ERROR" ]
then
    mail "Everything went right"
else
    mail "$ERROR"
fi

exit 0
