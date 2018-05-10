#!/bin/bash

set -euo pipefail

NGINX_ROOT=${NGINX_ROOT:=/var/www}

sed -i -e "s/error_reporting =.*=/error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT/g" /etc/php/5.6/fpm/php.ini
sed -i -e "s/display_errors =.*/display_errors = Off/g" /etc/php/5.6/fpm/php.ini

procs=$(cat /proc/cpuinfo |grep processor | wc -l)
sed -i -e "s/worker_processes 5/worker_processes $procs/" /etc/nginx/nginx.conf

sed -i -e "s#%%NGINX_ROOT%%#$NGINX_ROOT#" /etc/nginx/sites-available/default.conf

set +e
chown -Rf www-data.www-data $NGINX_ROOT
set -e

if [ $# -gt 0 ]; then
  args=("$@")
  argn=$#

  for i in $(seq $argn)
  do
    echo "${args[$i-1]}" >> /etc/cron.d/crontasks
  done
fi

chmod 600 /etc/cron.d/crontasks
crontab /etc/cron.d/crontasks

/usr/bin/supervisord -n -c /etc/supervisord.conf