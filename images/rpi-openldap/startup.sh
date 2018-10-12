#!bin/bash

# if [ -f "${BKP_FILE}" ]; then
#     rm -f /var/lib/ldap/*
#     /usr/sbin/slapadd -l "${BKP_FILE}"
#     chown -R openldap:openldap /var/lib/ldap/*
# else
#     echo "Warning: No LDAP backup file found!"
# fi

# https://github.com/moby/moby/issues/8231#issuecomment-63871343
ulimit -n 1024

# Passwords
if [ ! -z $LDAP_ADMIN_PWD_FILE -a -f $LDAP_ADMIN_PWD_FILE ]; then
    LDAP_ADMIN_PWD=`cat $LDAP_ADMIN_PWD_FILE`;
fi
if [ ! -z $LDAP_MAIL_PWD_FILE -a -f $LDAP_MAIL_PWD_FILE ]; then
    LDAP_MAIL_PWD=`cat $LDAP_MAIL_PWD_FILE`;
fi
if [ ! -z $LDAP_NEXTCLOUD_PWD_FILE -a -f $LDAP_NEXTCLOUD_PWD_FILE ]; then
    LDAP_NEXTCLOUD_PWD=`cat $LDAP_NEXTCLOUD_PWD_FILE`;
fi
if [ ! -z $LDAP_GOGS_PWD_FILE -a -f $LDAP_GOGS_PWD_FILE ]; then
    LDAP_GOGS_PWD=`cat $LDAP_GOGS_PWD_FILE`;
fi

echo slapd slapd/internal/generated_adminpw password ${LDAP_ADMIN_PWD} | debconf-set-selections \
    && echo slapd slapd/internal/adminpw password ${LDAP_ADMIN_PWD} | debconf-set-selections \
    && echo slapd slapd/password2 password ${LDAP_ADMIN_PWD} | debconf-set-selections \
    && echo slapd slapd/password1 password ${LDAP_ADMIN_PWD} | debconf-set-selections \
    && echo slapd slapd/dump_database_destdir string /var/backups/slapd-VERSION | debconf-set-selections \
    && echo slapd slapd/domain string ${LDAP_DOMAIN} | debconf-set-selections \
    && echo slapd shared/organization string ${LDAP_ORGANIZATION} | debconf-set-selections \
    && echo slapd slapd/purge_database boolean true | debconf-set-selections \
    && echo slapd slapd/move_old_database boolean true | debconf-set-selections \
    && echo slapd slapd/allow_ldap_v2 boolean false | debconf-set-selections \
    && echo slapd slapd/no_configuration boolean false | debconf-set-selections \
    && echo slapd slapd/dump_database select when needed | debconf-set-selections \
    && dpkg-reconfigure -f noninteractive slapd


echo "Starting server"
/usr/sbin/slapd -h 'ldap:/// ldapi:///' -g openldap -u openldap -F /etc/ldap/slapd.d & # -d 7 &
#pid="$!"
#echo $pid
for i in {30..0}; do
    ldapsearch -x -w ${LDAP_ADMIN_PWD} -D cn=admin,dc=${LDAP_DOMAIN},dc=${LDAP_EXTENSION} -b dc=${LDAP_DOMAIN},dc=${LDAP_EXTENSION} -LLL # &> /dev/null
    r="$?"
    echo result $r
    # TODO: it returns 49, Bad Credentials,
    # but as long as it's not 255 (Can't contact), it's started
    #if [ "$r" -eq 0 ]; then
    if [ "$r" -ne 255 ]; then
        break
    fi
    echo 'LDAP init process in progress...'
    sleep 1
done
if [ "$i" = 0 ]; then
    echo >&2 'LDAP init process failed.'
    exit 1
fi

function replace {
    echo $1
    sed -i "s/\${LDAP_ORGANIZATION}/${LDAP_ORGANIZATION}/g" $1
    sed -i "s/\${LDAP_EXTENSION}/${LDAP_EXTENSION}/g" $1
    sed -i "s/\${LDAP_DOMAIN}/${LDAP_DOMAIN}/g" $1
    sed -i "s/\${VOLUMES_PATH}/${VOLUMES_PATH//\//\\/}/g" $1
    sed -i "s/\${LDAP_MAIL_UID}/${LDAP_MAIL_UID}/g" $1
    sed -i "s/\${LDAP_NEXTCLOUD_UID}/${LDAP_NEXTCLOUD_UID}/g" $1
    sed -i "s/\${LDAP_GOGS_UID}/${LDAP_GOGS_UID}/g" $1
    sed -i "s/\${LDAP_MAIL_PWD}/${LDAP_MAIL_PWD}/g" $1
    sed -i "s/\${LDAP_NEXTCLOUD_PWD}/${LDAP_NEXTCLOUD_PWD}/g" $1
    sed -i "s/\${LDAP_GOGS_PWD}/${LDAP_GOGS_PWD}/g" $1
}
ldapadd -Y EXTERNAL -H ldapi:/// -f /tmp/data/_postfix-book.ldif
for i in `ls /tmp/data/[^_]*.ldif`; do
    replace $i
    #echo ldapadd -w ${LDAP_ADMIN_PWD} -D "cn=admin,dc=${LDAP_ORGANIZATION},dc=${LDAP_EXTENSION}" -f $i
    ldapadd -w ${LDAP_ADMIN_PWD} -D "cn=admin,dc=${LDAP_ORGANIZATION},dc=${LDAP_EXTENSION}" -f $i
done;
# Del 3 ACLs
for i in 1 2 3; do
    ldapmodify  -Y EXTERNAL -H ldapi:/// -f /tmp/data/_acl_del.ldif;
done
# Add 2 ACLs
replace /tmp/data/_acl_add_0.ldif;
ldapmodify  -Y EXTERNAL -H ldapi:/// -f /tmp/data/_acl_add_0.ldif
replace /tmp/data/_acl_add_1.ldif;
ldapmodify  -Y EXTERNAL -H ldapi:/// -f /tmp/data/_acl_add_1.ldif

echo "Stopping server"
pid=$(ps -U openldap -o pid=)
#echo $pid
if [ ! -z "$pid" ] && ! kill -s TERM "$pid" ; then
    echo >&2 'LDAP stop process failed.'
    #exit 1
fi
#ps -e -o user,pid,command

rm -Rf /tmp/data

echo "Restarting server"
/usr/sbin/slapd -h 'ldap:/// ldapi:///' -g openldap -u openldap -F /etc/ldap/slapd.d -d${DEBUG_LEVEL}
