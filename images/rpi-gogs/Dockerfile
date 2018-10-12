FROM resin/raspberrypi3-debian:latest

ENV GO_VERSION 1.9
ENV GO_OS linux
ENV GO_ARCH armv6l
ENV GOGS_CUSTOM /data/gogs
ENV GIT_HOME /home/git

# Install dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       git wget openssh-server mariadb-client \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /data/gogs/data \
    && mkdir -p /data/gogs/conf \
    && mkdir -p /data/gogs/log \
    && mkdir -p /data/gogs/gogs-repositories \
    && mkdir -p /data/ssh

# Create git user for Gogs
RUN export PUID=${PUID:-1000} \
    && export PGID=${PGID:-1000} \
    && addgroup --gid ${PGID} git \
    && adduser --uid ${PUID} --ingroup git --disabled-login --gecos 'Gogs Git User' --home ${GIT_HOME} --shell /bin/bash git \
    && ln -s /data/ssh ${GIT_HOME}/.ssh

RUN chown -R git:git /data
RUN chown -R git:git ${GIT_HOME}


RUN echo "export GOGS_CUSTOM=${GOGS_CUSTOM}" > /etc/profile.d/gogs.sh
RUN echo "export GOROOT=${GIT_HOME}/local/go" | tee -a /etc/profile.d/gogs.sh /etc/bash.bashrc > /dev/null \
    && echo "export GOPATH=${GIT_HOME}/go" | tee -a /etc/profile.d/gogs.sh /etc/bash.bashrc > /dev/null \
    && echo 'export PATH=$PATH:$GOROOT/bin:$GOPATH/bin' | tee -a /etc/profile.d/gogs.sh /etc/bash.bashrc > /dev/null

# ############## USER git ########################

USER git

# Install Golang
RUN cd $HOME \
    && mkdir local \
    && cd local \
    && wget https://storage.googleapis.com/golang/go${GO_VERSION}.${GO_OS}-${GO_ARCH}.tar.gz \
    && tar zxvf go${GO_VERSION}.${GO_OS}-${GO_ARCH}.tar.gz \
    && rm go${GO_VERSION}.${GO_OS}-${GO_ARCH}.tar.gz

# Install Gogs
RUN . /etc/profile.d/gogs.sh \
    && ${GOROOT}/bin/go get -u -tags "cert" github.com/gogits/gogs \
    && cd $GOPATH/src/github.com/gogits/gogs \
    && go build -tags "cert"

# TODO:
# clean stuff
# https://github.com/gogits/gogs/blob/master/docker/finalize.sh

# Clean stuff
RUN rm -r $HOME/go/src/github.com/gogits/gogs/.git
#RUN rm -r $HOME/local

# Configuration
# $HOME doesn't work with COPY
RUN mkdir -p ${GIT_HOME}/go/src/github.com/gogits/gogs/custom/conf
COPY app.ini ${GIT_HOME}/go/src/github.com/gogits/gogs/custom/conf/
# LDAP
RUN mkdir -p ${GIT_HOME}/go/src/github.com/gogits/gogs/custom/conf/auth.d
COPY ldap.conf ${GIT_HOME}/go/src/github.com/gogits/gogs/custom/conf/auth.d/

# ############## USER root ########################

USER root

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh

#ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
#CMD gosu git ${GOPATH}/src/github.com/gogits/gogs/gogs web
ENTRYPOINT []
CMD ["/usr/local/bin/docker-entrypoint.sh"]
