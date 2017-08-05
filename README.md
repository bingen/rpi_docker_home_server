# Docker Home Server for Raspberry Pi

Flash Hypriot
-------------

You can check last images [here](http://blog.hypriot.com/downloads/) and use [flash tool](https://github.com/hypriot/flash) to flash your RespberryPi SD:

    flash --hostname your-hostname https://github.com/hypriot/image-builder-rpi/releases/download/v1.4.0/hypriotos-rpi-v1.4.0.img.zip

SSH into each RPI:

    ssh pirate@you-rpi-ip

As of version 1.4, default credentials are pirate/hypriot. You can use arp-scan to guess the IP. You can also use:

    function getip() { (traceroute $1 2>&1 | head -n 1 | cut -d\( -f 2 | cut -d\) -f 1) }

Change default password:

    passwd

You can also set up paswwordless access with:

    ssh-copy-id -i ~/.ssh/your-key_rsa.pub pirate@your-rpi -o "IdentitiesOnly yes"

And also add an entry to you ~/.ssh/config file:

    Host your-rpi-1 your-rpi-2 ...
        Hostname %h.local
        User pirate
        IdentityFile ~/.ssh/your-key_rsa
        IdentitiesOnly yes
        StrictHostKeyChecking no

If you want, you can also add this config snippet to all your nodes and add your private key to each `~/.ssh` folder to be able to connect from one RPI to another.

(?) Add regular user to docker group

    sudo usermod -aG docker pirate

(Optional) In case you see annoying warning messages about locales from perl:

    sudo dpkg-reconfigure locales

(Optional) Install some useful packages

    sudo aptitude update && sudo aptitude install rsync zsh

(Optional) Encrypt external hard disk
-------------------------------------

    sudo aptitude install cryptsetup
    sudo fdisk /dev/sdX
    sudo cryptsetup --verify-passphrase luksFormat /dev/sdX1 -c aes -s 256 -h sha256
    sudo cryptsetup luksOpen /dev/sdX1 volumes
    sudo mkfs -t ext4 -m 1 -O dir_index,sparse_super /dev/mapper/volumes
    #mount -t auto /dev/mapper/volumes /media/volumes

    sudo dd if=/dev/urandom of=/root/volumes_luks_pwd bs=1024 count=4
    sudo chmod 0400 /root/volumes_luks_pwd
    sudo cryptsetup luksAddKey /dev/sdX1 /root/volumes_luks_pwd

Add to /etc/crypttab:

    volumes      /dev/disk/by-uuid/uuid-of-your-drive  /root/volumes_luks_pwd  luks

and add to /etc/fstab:

    /dev/mapper/volumes  /media/volumes     ext4    defaults        0       2

NFS
---

Install server on main host:

    sudo aptitude install nfs-kernel-server
    sudo mkdir -p /export/volumes
    sudo mount --bind /media/volumes /export/volumes

And add the following line to /etc/fstab toavoid repeating it on startup:

    /media/volumes       /export/volumes    none    bind            0       0

And to /etc/exports:

    /export         192.168.1.0/24(rw,fsid=0,insecure,no_subtree_check,async)
    /export/volumes 192.168.1.0/24(rw,nohide,insecure,no_subtree_check,async,no_root_squash)

(changing network/mask by your local values)

On the other nodes:

    sudo aptitude install nfs-common

And add to fstab:

    your-main-host:/export/volumes /media/volumes nfs auto,user 0 0

Swap file
---------

http://jermsmit.com/my-raspberry-pi-needs-a-swap/

    dd if=/dev/zero of=/media/volumes/swap bs=1M count=2048
    chmod 600 /media/volumes/swap
    mkswap /media/volumes/swap
    swapon /media/volumes/swap

Add to /etc/fstab:

    /media/volumes/swap               swap                    swap    defaults        0 0

Repeat for worker nodes (changing name of swap file)

Swarm
-----

Login to the main RPI and start the swarm:

    docker swarm init --listen-addr eth0

And join from the other ones, just copy-paste command provided by the master from them:

    docker swarm join --token your-token your-main_rpi:2377


Data and volumes
----------------

If you have existing data, create folders (otherwise setup script will do it) and copy it data:

    sudo mkdir -p /media/volumes/mail/data
    sudo mkdir -p /media/volumes/mail/state
    sudo mkdir -p /media/volumes/nextcloud

    sudo chown -R pirate:pirate /media/volumes/*

    sudo mkdir -p /media/volumes/openldap/data
    sudo mkdir -p /media/volumes/openldap/config
    sudo mkdir -p /media/volumes/openldap/certs
    sudo chown -R 999 /media/volumes/openldap*

From your current installation:

    rsync -auv --delete -e "ssh -i ~/.ssh/your-key_rsa" /var/www/nextcloud/data your-main-host:/media/volumes/nextcloud/
    mysqldump --lock-tables -u nextcloud -p -h localhost nextcloud > /var/www/nextcloud/nextcloud_db_backup.sql
    rsync -auv --delete -e "ssh -i ~/.ssh/your-key_rsa" /srv/vmail/ your-main-host:/media/volumes/mail/data


Configuration and deployment
----------------------------

First download the repos:

    git@github.com:bingen/rpi_docker_home_server.git
    git submodule update --init --recursive

Set up your preferences:

    ./setup.sh

(Optional, can be downloaded from registry, unless you changed them) Build aux images:

    cd ~/docker_home_server/images/rpi-nginx
    docker build . -t bingen/rpi-nginx
    cd ~/docker_home_server/images/rpi-nginx-php5
    docker build . -t bingen/rpi-nginx-php5
    cd ../../

(Optional, can be downloaded from registry, unless you changed them) Build images:

    docker-compose build

Deploy docker stack

    deploy.sh your-stack-name

Other useful commands
---------------------

    docker node ls

    docker stack ls
    docker stack ps your-stack-name

To see logs of a docker swarm/stack service [reference](https://github.com/docker/docker/issues/23710):

    docker logs $(docker inspect --format "{{.Status.ContainerStatus.ContainerID}}" `docker stack ps your-stack-name | grep your-service-name | cut -f1 -d' '`)

To shutdown the stack:

    docker stack rm your-stack-name

To get into containers:

    docker ps # in the swarm node containing it
    docker exec -ti 5105b27d9cf0 bash

To view swarm token:

    docker swarm join-token worker

I was experience the issue described and fixed [here](Docker swarm nodes down after reboot!
https://forums.docker.com/t/docker-worker-nodes-shown-as-down-after-re-start/22329/8?u=bingen):

To avoid swarm nodes showing up as Down on reboot, you can do:

    sudo crontab -e

then add a line like this

    @reboot docker ps

Openldap
--------

    ldapsearch -x -w your-admin-ldap-password -D cn=admin,dc=your-domain,dc=com -b dc=your-domain,dc=com -LLL

To reset a user's password:
Copy this into a file, `user_pwd.ldif`:

    dn: uniqueIdentifier=your-user,ou=people,dc=your-domain,dc=com
    changetype: modify
    replace: userPassword
    userPassword: {SSHA}Djpd2d+kbQm4ftHupSaS65wl8l8EbDot

And the run:

    ldapadd -W -D "cn=admin,dc=your-domain,dc=com" -f user_pwd.ldif

You generate the password with:

    slappasswd -s your-password

MariaDB
-------

If you have existing data, make sure root password matches and access from outside ('%') is allowed.

Nextcloud
---------

After first run, set DATA_CHOWN=0. Otherwise every time you deploy the whole folder with all your data will be recursed to change ownership, and it can take long when it's only needed for the first time.

Need to log in as admin for the first time and enable Apps manually.

Dynamic DNS
-----------

Check your domain registration provider

Fail2ban
--------

Install fail2ban in you docker swarm master node if you want to allow ssh connections from outside.

    sudo aptitude install fail2ban

Have a look at the [documentation](http://www.fail2ban.org/wiki/index.php/MANUAL_0_8) for configuration.

Port mapping
------------

Get into your router admin page and redirect ports:

- `80`, `443` for Web (Nextcloud and eventually other through HaProxy)
- `25`, `143`, `587`, `993` for mail server
- `22` for ssh

to your docker swarm master node IP.

TODO
----

- Install and enable Nextcloud apps automatically
- Let's Encrypt
- DNS
- XMPP
- Wordpress
- Gitlab
- VPN
- Opens social networks (GNU social, Diaspora)
- Transmission
- Sia storage
- Use PHP7 for Nextcloud
- Alternative: run your own registry for images.
