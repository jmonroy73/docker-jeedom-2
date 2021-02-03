﻿# choix de la version debian:
# stretch = debian 9 (les box smart & co)
# buster = debian 10 (les DIY)
FROM php:7.3-apache-buster

LABEL version="jeedom for debian buster"

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
	supervisor \
	python python-pip python3 python-dev python3-pip python-virtualenv \
	libzip-dev zip \
	git \
	mariadb-client \
	systemd gettext librsync-dev \
	sudo && \
# add php extension
    docker-php-ext-install pdo pdo_mysql zip && \
# add the jeedom cron task
#	echo "* * * * *  /usr/bin/php /var/www/html/core/php/jeeCron.php >> /dev/null" > /etc/cron.d/jeedom && \
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


# Copy hello-cron file to the cron.d directory
COPY jeedom.cron.txt /etc/cron.d/jeedom

# Give execution rights on the cron job
RUN chmod 0644 /etc/cron.d/jeedom

# Apply cron job
RUN crontab /etc/cron.d/jeedom

# choix de la version jeedom:
# master = 3.xx (valeur par défaut)
# V4-stable
# alpha = v4.1
ARG jeedom_version=V4-stable

# choix de GIT CLONE
# RUN git clone https://github.com/jeedom/core.git -b ${jeedom_version} /var/www/html

# choix du download direct
RUN wget https://github.com/jeedom/core/archive/${jeedom_version}.zip -O /tmp/jeedom.zip
RUN mkdir -p /var/www/html
RUN unzip -q /tmp/jeedom.zip -d /root/
RUN cp -R /root/core-*/* /var/www/html
RUN cp -R /root/core-*/.[^.]* /var/www/html
RUN rm -rf /root/core-* > /dev/null 2>&1
RUN rm /tmp/jeedom.zip

# for beta: remove anoying .htaccess
RUN rm /var/www/html/install/.htaccess

# use supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Create the log file to be able to run tail
RUN touch /var/www/html/log/cron.log

# USER www-data:www-data
# USER root

VOLUME  /var/www/html/backup

# try restore backup if exist
# RUN php install/restore.php

# Initialisation 
# ADD install/OS_specific/Docker/init.sh /root/init.sh
# RUN chmod +x /root/init.sh
# CMD ["sh", "/root/init.sh"]


#   prepare db config file:
#   mv /app/core/config/common.config.sample.php /app/core/config/common.config.php && \
#   sed -ri -e 's!#HOST#!db!g' /app/core/config/common.config.php  && \
#   sed -ri -e 's!#PORT#!3306!g' /app/core/config/common.config.php  && \
#   sed -ri -e 's!#DBNAME#!jeedom!g' /app/core/config/common.config.php  && \
#   sed -ri -e 's!#USERNAME#!jeedom!g' /app/core/config/common.config.php  && \
#   sed -ri -e 's!#PASSWORD#!jeedom!g' /app/core/config/common.config.php

# Run the command on container startup
# CMD (crond -l -f 8 & ) && apache2-foreground

# run supervisor 
CMD ["/usr/bin/supervisord"]