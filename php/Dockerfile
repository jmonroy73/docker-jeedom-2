FROM php:7.3-apache-buster

ENV JEEDOM_BRANCH=beta
ENV MYSQL_JEEDOM_DATABASE=jeedom
ENV MYSQL_JEEDOM_USER=jeedom
# ENV MYSQL_JEEDOM_PASSWD
# ENV MYSQL_ROOT_PASSWORD
ENV MYSQL_HOST=db
ENV JEEDOM_BRANCH=beta

LABEL version="Jeedom for Docker"

# Installation des paquets
# 	ccze          : couleur pour les logs
# 	wget          : téléchargement
#   libzip-dev zip: pour l'extension php zip
#   sudo          : pour les droits sudo de jeedom
#   python*       : pour certains plugins
#   mariadb-client: pour backup et restauration

RUN apt-get update && apt-get install -y \
	apt-utils \
	net-tools \
	wget \
	ntp \
	locales \
	ccze \
	python python-pip python3 python-dev python3-pip python-virtualenv \
	libzip-dev zip \
	git \
	mariadb-client \
	gettext librsync-dev \
	sudo at \
  libssh2-1 libssh2-1-dev

# libc-client-dev libkrb5-dev : for imap extension
# libc-client2007e-dev libpng-dev : for gd extension
# libxml2-dev : xmlrpc extension
# libldb-dev libldap2-dev : ldap extension
RUN apt install -y libc-client-dev libkrb5-dev libxml2-dev \
     libc-client2007e-dev libldb-dev libldap2-dev  libpng-dev && \
  rm -r /var/lib/apt/lists/*
  
# add php extension
RUN pecl install ssh2-1.3.1
RUN docker-php-ext-enable ssh2
RUN docker-php-ext-configure imap --with-kerberos --with-imap-ssl
RUN docker-php-ext-configure ldap # --with-libdir=lib/x86_64-linux-gnu/
RUN docker-php-ext-install sockets pdo pdo_mysql zip gd imap opcache xmlrpc ldap && \
# add sudo for www-data
    echo "www-data ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/90-mysudoers

# add manually duplicity v0.7.19 from jeedom image
RUN python -m pip install future fasteners && \
    wget https://images.jeedom.com/resources/duplicity/duplicity.tar.gz -O /tmp/duplicity.tar.gz && \
    tar xvf /tmp/duplicity.tar.gz -C /tmp && \
	cd /tmp/duplicity-0.7.19 && \
	python setup.py install 2>&1 >> /dev/null && \
	rm -rf /tmp/duplicity.tar.gz && \
	rm -rf duplicity-0.7.19

# install composer for dependancies
# COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer
# RUN composer install

#add motd - link sh to bash for Docker Desktop
COPY motd /etc/jmotd
RUN echo '[ ! -z "$TERM" -a -r /etc/motd ] && cat /etc/issue && cat /etc/motd && cat /etc/jmotd' \
    >> /etc/bash.bashrc && \
	ln -sf /bin/bash /bin/sh

RUN cp /usr/local/etc/php/php.ini-development /usr/local/etc/php/php.ini

# Change uid and gid of apache to docker user uid/gid - create /tmp/jeedom
RUN usermod -u 1000 www-data \
   && groupmod -g 1000 www-data \
   && mkdir -p /tmp/jeedom \
   && chmod 777 -R /tmp/jeedom \
   && chown www-data:www-data -R /tmp/jeedom

WORKDIR /var/www/html
VOLUME  /var/www/html

# Initialisation 
ADD init.sh /root/init.sh
RUN chmod +x /root/init.sh
ENTRYPOINT ["/root/init.sh"]

