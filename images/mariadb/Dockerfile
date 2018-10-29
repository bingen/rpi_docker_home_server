#
# MariaDB Dockerfile

# Pull base image.
FROM debian:stretch

ENV DEBIAN_FRONTEND=noninteractive

# Install MariaDB.
RUN \
  apt-get update && \
  apt-get upgrade -y  && \
  apt-get -y install mariadb-server procps

RUN  find /etc/mysql/ -name *.cnf -exec sed -i 's/^\(bind-address\s.*\)/# \1/' {} \;
#RUN \
#  find /etc/mysql/ -name *.cnf -exec sed -i 's/^\(bind-address\s.*\)/# \1/' {} \; && \
#  echo "mysqld_safe &" > /tmp/config && \
#  echo "mysqladmin --silent --wait=30 ping || exit 1" >> /tmp/config && \
#  echo "mysql -e 'GRANT ALL PRIVILEGES ON *.* TO \"root\"@\"%\" WITH GRANT OPTION;'" >> /tmp/config && \
#  bash /tmp/config && \
#  mysql -e "SELECT Host, User, Password FROM mysql.user;" > /tmp/a.out
  #rm -f /tmp/config

COPY tuning.cnf /etc/mysql/conf.d/tuning.cnf

COPY tuning-primer.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/tuning-primer.sh
COPY mysqltuner.pl /usr/local/bin/
RUN chmod +x /usr/local/bin/mysqltuner.pl

COPY startup.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/startup.sh

# Define mountable directories.
#VOLUME ["/var/lib/mysql"]

# Define default command.
CMD ["/usr/local/bin/startup.sh"]

# Expose ports.
EXPOSE 3306
