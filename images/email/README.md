Based on:

http://acidx.net/wordpress/2014/06/installing-a-mailserver-with-postfix-dovecot-sasl-ldap-roundcube/

Copy your getmail configurations into `MAIL_DATA_PATH` volume, in `getmail` folder. They can not be built in the container as might contain sensitive information.
