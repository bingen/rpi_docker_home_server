FROM resin/raspberrypi3-debian:latest

# Install dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       openssh-server \
    && rm -rf /var/lib/apt/lists/*

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D"]
