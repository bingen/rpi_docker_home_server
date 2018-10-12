#
# MariaDB Dockerfile
#
# https://github.com/bingen/rpi-mariadb
#

# Pull base image.
FROM resin/raspberrypi3-debian:latest

ENV DEBIAN_FRONTEND=noninteractive

# Install MariaDB.
RUN \
  apt-get update && \
  apt-get upgrade  && \
  apt-get -y install mariadb-server
RUN \
  sed -i 's/^\(bind-address\s.*\)/# \1/' /etc/mysql/my.cnf && \
  echo "mysqld_safe &" > /tmp/config && \
  echo "mysqladmin --silent --wait=30 ping || exit 1" >> /tmp/config && \
  echo "mysql -e 'GRANT ALL PRIVILEGES ON *.* TO \"root\"@\"%\" WITH GRANT OPTION;'" >> /tmp/config && \
  bash /tmp/config && \
  mysql -e "SELECT Host, User, Password FROM mysql.user;" > /tmp/a.out
  #rm -f /tmp/config

COPY startup.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/startup.sh

# Define mountable directories.
#VOLUME ["/var/lib/mysql"]

# Define default command.
CMD ["/usr/local/bin/startup.sh"]

# Expose ports.
EXPOSE 3306
