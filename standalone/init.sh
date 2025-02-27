#!/bin/sh
VERT="\\033[1;32m"
NORMAL="\\033[0;39m"
ROUGE="\\033[1;31m"
ROSE="\\033[1;35m"
BLEU="\\033[1;34m"
BLANC="\\033[0;02m"
BLANCLAIR="\\033[1;08m"
JAUNE="\\033[1;33m"
CYAN="\\033[1;36m"

log_error() {
  echo "${ROUGE}$@${NORMAL}"
}

log_warn() {
  echo "${JAUNE}$@${NORMAL}"
}

log_info() {
  echo "${VERT}$@${NORMAL}"
}

log_debug() {
  echo "${BLEU}$@${NORMAL}"
}

mysql_sql() {
  echo "$@" | mysql -uroot "-p${MYSQL_ROOT_PASSWORD}"
  if [ $? -ne 0 ]; then
    log_error "Ne peut exécuter $@ dans MySQL - Annulation"
    exit 1
  fi
}

log_info "starting jeedom ${JEEDOM_BRANCH}"
cd /var/www/html

if [ ! -f "/var/www/html/index.php" ]; then
    log_debug "git clone jeedom ${JEEDOM_BRANCH}"
    git clone https://github.com/jeedom/core.git -b ${JEEDOM_BRANCH} .
fi

if [ ! -f "/var/www/html/core/config/common.config.php" ]; then
  if [ ! -f "/var/www/html/core/config/common.config.sample.php" ]; then
    log_error "Can not install jeedom (no config.sample file)"
    exit 1
  fi

  log_info "first run of jeedom container : configuration"
  cp /var/www/html/core/config/common.config.sample.php /var/www/html/core/config/common.config.php
  sed -i "s/#PASSWORD#/${MYSQL_JEEDOM_PASSWD}/g" /var/www/html/core/config/common.config.php
  sed -i "s/#DBNAME#/${MYSQL_JEEDOM_DATABASE}/g" /var/www/html/core/config/common.config.php
  sed -i "s/#USERNAME#/${MYSQL_JEEDOM_USER}/g" /var/www/html/core/config/common.config.php
  sed -i "s/#PORT#/3306/g" /var/www/html/core/config/common.config.php
  sed -i "s/#HOST#/${MYSQL_HOST}/g" /var/www/html/core/config/common.config.php
  chmod 775 -R /var/www/html
  chown -R www-data:www-data /var/www/html
  mkdir -p /tmp/jeedom
  chmod 777 -R /tmp/jeedom
  chown www-data:www-data -R /tmp/jeedom

  log_info "Création de la database SQL ${MYSQL_JEEDOM_DATABASE}..."
  mysql_sql "DROP USER IF EXISTS '${MYSQL_JEEDOM_USER}'@'%';"
  mysql_sql "CREATE USER '${MYSQL_JEEDOM_USER}'@'%' IDENTIFIED BY '${MYSQL_JEEDOM_PASSWD}';"
  mysql_sql "DROP DATABASE IF EXISTS ${MYSQL_JEEDOM_DATABASE};"
  mysql_sql "CREATE DATABASE ${MYSQL_JEEDOM_DATABASE};"
  mysql_sql "GRANT ALL PRIVILEGES ON ${MYSQL_JEEDOM_DATABASE}.* TO '${MYSQL_JEEDOM_USER}'@'%';"

  log_info "jeedom clean install"
  php /var/www/html/install/install.php mode=force
  if [ $? -ne 0 ]; then
    log_error "Can not install jeedom (error in install.php, see log)"
    exit 1
  fi

  log_warn "vérification de jeedom"
  echo "* * * * * www-data /usr/bin/php ${WEBSERVER_HOME}/core/php/jeeCron.php >> /dev/null" > /etc/cron.d/jeedom
  if [ $? -ne 0 ]; then
    log_error "Ne peut installer le cron de jeedom - Annulation"
    exit 1
  fi

  echo "*/5 * * * * root /usr/bin/php ${WEBSERVER_HOME}/core/php/watchdog.php >> /dev/null" > /etc/cron.d/jeedom_watchdog
  if [ $? -ne 0 ]; then
    log_error "Ne peut installer le cron de jeedom - Annulation"
    exit 1
  fi

  echo "www-data ALL=(ALL) NOPASSWD: ALL" | (EDITOR="tee -a" visudo)
  if [ $? -ne 0 ]; then
    log_error "Ne peut permettre à jeedom d'utiliser sudo - Annulation"
    exit 1
  fi

  log_warn "vérification de jeedom"
  php ${WEBSERVER_HOME}/sick.php

  if [ -d "/tmp/backup" ] && [ "$(ls -A /tmp/backup)" ]; then
     log_info "found a backup, try to restore..."
     cp /tmp/backup/* /var/www/html/backup
     php /var/www/html/install/restore.php
  fi
  log_info " ___ successfull new installation ! ___"
fi

# start all services 

systemctl daemon-reload
log_info " ___ Start mysql ___"
service mysql start
service mysql status
if [ $? -ne 0 ]; then
  log_error "Ne peut lancer mysql - Annulation"
  exit 1
fi

log_info " ___ Start fail2ban ___"
service fail2ban start 
if [ $? -ne 0 ]; then
  log_error "Ne peut lancer fail2ban - Annulation"
  exit 1
fi

sysctl vm.swappiness=10

a2dismod status
a2enmod headers
a2enmod remoteip
  
# start at daemon
atd

# start apache
exec apache2-foreground
