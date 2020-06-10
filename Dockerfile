# download jeedom source from github
FROM alpine AS jeedom-src

# choix de la version jeedom:
# master = 3.xx (valeur par défaut)
# V4-stable
# alpha = v4.1
ARG jeedom_version=master

RUN apk update && apk add --no-cache git && \
   git clone https://github.com/jeedom/core.git -b ${jeedom_version} /app

#   && \
#   mv /app/core/config/common.config.sample.php /app/core/config/common.config.php && \
#   sed -ri -e 's!#HOST#!db!g' /app/core/config/common.config.php  && \
#   sed -ri -e 's!#PORT#!3306!g' /app/core/config/common.config.php  && \
#   sed -ri -e 's!#DBNAME#!jeedom!g' /app/core/config/common.config.php  && \
#   sed -ri -e 's!#USERNAME#!jeedom!g' /app/core/config/common.config.php  && \
#   sed -ri -e 's!#PASSWORD#!jeedom!g' /app/core/config/common.config.php

# choix de la version debian:
# stretch = debian 9 (les box smart & co)
# buster = debian 10 (les DIY)
FROM php:7.3-apache-buster

LABEL version="jeedom for debian ${os_version}"

# Installation des paquets
# 	ccze          : couleur pour les logs
# 	wget          : téléchargement
#   libzip-dev zip: pour l'extension php zip
#   sudo          : pour les droits sudo de jeedom
#   python*       : pour certains plugins
#   mariadb-client: pour backup et restauration

RUN apt-get update && apt-get install -y \
	apt-utils \
	wget \
	ntp \
	locales \
	ccze \
	cron \
	python python-pip python3 python-dev python3-pip python-virtualenv \
	libzip-dev zip \
	git \
	mariadb-client \
	systemd gettext duplicity librsync-dev \
	sudo && \
# add php extension
    docker-php-ext-install pdo pdo_mysql zip && \
# add the jeedom cron task
	echo "* * * * *  /usr/bin/php /var/www/html/core/php/jeeCron.php >> /dev/null" > /etc/cron.d/jeedom && \
# add sudo for www-data
    echo "www-data ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/90-mysudoers

# Reduce image size : inutile car jeedom a besoin d'ajouter des dépendances
#    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --chown=www-data:www-data --from=jeedom-src /app/ /var/www/html/

# Initialisation 
# ADD install/OS_specific/Docker/init.sh /root/init.sh
# RUN chmod +x /root/init.sh
# CMD ["sh", "/root/init.sh"]
