FROM bingen/amd64-nginx

# Add PHP 7.2 repo
RUN apt-get update && \
    apt-get install -y apt-transport-https lsb-release ca-certificates wget && \
    wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg && \
    sh -c 'echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'
# update and install php
RUN apt-get update && \
    apt-get install -y php7.2 php7.2-fpm php-pear php7.2-common \
    php7.2-mysql php7.2-cli php7.2-gd php7.2-curl php-apcu php7.2-opcache \
    php7.2-mbstring php7.2-ldap php7.2-zip && \
    apt-get clean

# overwrite the default-configuration with our own settings - enabling PHP
COPY default /etc/nginx/sites-available/default

CMD service php7.2-fpm start && nginx