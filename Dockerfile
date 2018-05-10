FROM ubuntu:18.04

MAINTAINER Guilherme Fontenele <guilherme@fontenele.net>

# envs
ENV DEFAULT_LOCALE=en_US
ENV NGINX_VERSION=stable
ENV DEBIAN_FRONTEND noninteractive
# update aptitude repositories
RUN apt-get update
# base
RUN apt-get install -y apt-utils net-tools wget git vim memcached software-properties-common npm curl
# supervisor
RUN apt-get install -y supervisor
# php5/nginx repositories
RUN add-apt-repository ppa:nginx/${NGINX_VERSION}
RUN add-apt-repository ppa:ondrej/php && apt-get update && apt-get upgrade -y
# php5
RUN apt-get install -y nginx php5.6-fpm php5.6-ssh2 php5.6-curl php5.6-intl php5.6-mcrypt php5.6-mbstring php5.6-pgsql \
    php5.6-sqlite php5.6-mysql php5.6-gd php5.6-memcache php5.6-memcached php5.6-xmlrpc php5.6-xsl php5.6-mongo php5.6-ldap php5.6-cli
# composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
# clean some space
RUN apt-get remove --purge -y software-properties-common
RUN apt-get autoremove -y
RUN apt-get clean
RUN apt-get autoclean
RUN echo -n > /var/lib/apt/extended_states && \
	rm -rf /var/lib/apt/lists/* && \
	rm -rf /usr/share/man/?? && \
	rm -rf /usr/share/man/??_*
RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
# nginx config
RUN sed -i -e"s/worker_processes  1/worker_processes 5/" /etc/nginx/nginx.conf && \
	sed -i -e"s/keepalive_timeout\s*65/keepalive_timeout 2/" /etc/nginx/nginx.conf && \
	sed -i -e"s/keepalive_timeout 2/keepalive_timeout 2;\n\tclient_max_body_size 128m;\n\tproxy_buffer_size 256k;\n\tproxy_buffers 4 512k;\n\tproxy_busy_buffers_size 512k/" /etc/nginx/nginx.conf && \
	echo "daemon off;" >> /etc/nginx/nginx.conf
# php config
RUN sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php/5.6/fpm/php.ini && \
	sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 900M/g" /etc/php/5.6/fpm/php.ini && \
	sed -i -e "s/;always_populate_raw_post_data\s*=\s*-1/always_populate_raw_post_data = -1/g" /etc/php/5.6/fpm/php.ini && \
	sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 900M/g" /etc/php/5.6/fpm/php.ini && \
	sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php/5.6/fpm/php-fpm.conf && \
	sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" /etc/php/5.6/fpm/pool.d/www.conf && \
	sed -i -e "s/pm.max_children = 5/pm.max_children = 9/g" /etc/php/5.6/fpm/pool.d/www.conf && \
	sed -i -e "s/pm.start_servers = 2/pm.start_servers = 3/g" /etc/php/5.6/fpm/pool.d/www.conf && \
	sed -i -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" /etc/php/5.6/fpm/pool.d/www.conf && \
	sed -i -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 4/g" /etc/php/5.6/fpm/pool.d/www.conf && \
	sed -i -e "s/pm.max_requests = 500/pm.max_requests = 200/g" /etc/php/5.6/fpm/pool.d/www.conf && \
	sed -i "s/;date.timezone =.*/date.timezone = America\/Los_Angeles/" /etc/php/5.6/fpm/php.ini && \
	sed -i "s/;date.timezone =.*/date.timezone = America\/Los_Angeles/" /etc/php/5.6/cli/php.ini
# php sock owner
RUN sed -i -e "s/;listen.mode = 0660/listen.mode = 0750/g" /etc/php/5.6/fpm/pool.d/www.conf && \
	find /etc/php/5.6/cli/conf.d/ -name "*.ini" -exec sed -i -re 's/^(\s*)#(.*)/\1;\2/g' {} \; && \
	mkdir /run/php && \
	# mcrypt configuration
	phpenmod mcrypt && \
	# Nginx site configuration
	rm -Rf /etc/nginx/conf.d/* && \
	rm -Rf /etc/nginx/sites-available/default && \
	mkdir -p /etc/nginx/ssl/ && \
	# create workdir directory
	mkdir -p /var/www
# https
RUN openssl req -batch -nodes -newkey rsa:2048 -keyout /etc/ssl/private/server.key -out /tmp/server.csr -subj "/C=BR/ST=DF/L=Brasilia/O=Dev/OU=FS/CN=localhost"
RUN openssl x509 -req -days 365 -in /tmp/server.csr -signkey /etc/ssl/private/server.key -out /etc/ssl/certs/server.crt
RUN rm /tmp/server.csr
# node
RUN npm cache clean -f && npm install -g n && n stable
# copy nginx virtualhost config
COPY ./nginx.conf /etc/nginx/sites-available/default.conf
# copy supervisor config
COPY ./supervisord.conf /etc/supervisord.conf
# start supervisord
COPY ./cmd.sh /
# mount www directory as a workdir
COPY ./www/ /var/www
# links
RUN rm -f /etc/nginx/sites-enabled/default && \
	ln -s /etc/nginx/sites-available/default.conf /etc/nginx/sites-enabled/default && \
	chmod 755 /cmd.sh && \
	chown -Rf www-data.www-data /var/www && \
	touch /var/log/cron.log && \
	touch /etc/cron.d/crontasks

# cmd aliases
RUN echo "alias l='ls -la'" >> /root/.bashrc
# vim config
RUN echo "syntax on" >> /root/.vimrc
RUN echo "set nu" >> /root/.vimrc
# expose ports
EXPOSE 80 443
# entrypoint
ENTRYPOINT ["/bin/bash", "/cmd.sh"]