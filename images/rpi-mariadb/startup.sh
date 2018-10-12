#!bin/bash

echo "Installing Mysql DB"
mysql_install_db --user=mysql --ldata=/var/lib/mysql

# set root password from secret
if [ ! -z $MYSQL_ROOT_PWD_FILE -a -f $MYSQL_ROOT_PWD_FILE ]; then
    MYSQL_ROOT_PWD=`cat $MYSQL_ROOT_PWD_FILE`;
fi

if [ ! -z $MYSQL_ROOT_PWD ]; then
    # start server
    echo "Starting server"
    /usr/bin/mysqld_safe --datadir='/var/lib/mysql' & #--skip-grant-tables &
    pid="$!"
    echo "Mysql pid: $pid"

    mysql=( mysql  )

    for i in {30..0}; do
        if echo 'SELECT 1' | "${mysql}" &> /dev/null; then
            break
        fi
        echo 'MySQL init process in progress...'
        sleep 1
    done
    if [ "$i" = 0 ]; then
        echo >&2 'MySQL init process failed or there already was data with a root password set.'
    fi

    # Allow access from outside
    #echo "INSERT INTO mysql.user (Host, User) VALUES ('%', 'root');" | "${mysql}"
    echo 'GRANT ALL PRIVILEGES ON *.* TO "root"@"%" WITH GRANT OPTION;' | "${mysql}"
    # set root password
    echo "Setting root password"
    #/usr/bin/mysqladmin -u root flush-privileges password "$MYSQL_ROOT_PWD"
    echo "UPDATE mysql.user SET password=PASSWORD('$MYSQL_ROOT_PWD') WHERE user='root';" | "${mysql}"
    #echo "SET PASSWORD FOR 'root' = PASSWORD('$MYSQL_ROOT_PWD');" | "${mysql}"
    if [ $? != 0 ]; then
        echo >&2 'MySQL root password setting failed.'
        #exit 1
    fi

    # Stop server
    echo "Stopping server"
    #if ! kill -s TERM "$pid" || ! wait "$pid"; then
    if ! mysqladmin -u root -p"$MYSQL_ROOT_PWD" shutdown || ! wait "$pid"; then
        echo >&2 'MySQL stop process failed.'
        #exit 1
    fi

fi

echo "Restarting server"
/usr/bin/mysqld_safe --datadir='/var/lib/mysql'
