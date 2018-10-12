FROM bingen/rpi-nginx

# update and install php5
RUN apt-get update && \
    apt-get install -y php7.0 php7.0-fpm php-pear php7.0-common php7.0-mcrypt \
    php7.0-mysql php7.0-cli php7.0-gd php7.0-curl php7.0-apcu php7.0-opcache \
    php7.0-mbstring php7.0-ldap php7.0-zip && \
    apt-get clean

# overwrite the default-configuration with our own settings - enabling PHP
COPY default /etc/nginx/sites-available/default

CMD service php7.0-fpm start && nginx