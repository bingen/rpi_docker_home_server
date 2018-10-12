FROM resin/raspberrypi3-debian:latest

RUN echo deb http://deb.debian.org/debian jessie-backports main  >> /etc/apt/sources.list
RUN apt-get update && apt-get install -y haproxy cron \
    && apt-get install certbot -t jessie-backports

RUN mkdir -p /run/haproxy

COPY haproxy.cfg /etc/haproxy/haproxy.cfg
COPY haproxy_letsencrypt.cfg /etc/haproxy/haproxy_letsencrypt.cfg

COPY startup.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/startup.sh

COPY letsencrypt.cron /usr/local/bin/
RUN chmod +x /usr/local/bin/letsencrypt.cron

#CMD haproxy -f /etc/haproxy/haproxy.cfg
CMD /usr/local/bin/startup.sh