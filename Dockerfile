#
# Dockerfile - Redmine
# Integrate Nginx + Redis + MariaDB with Redmine
#
# - Build
# docker build --rm -t redmine:latest .
#
# - Run
# docker run -d --name="redmine" -h "redmine" -p 80:80 redmine:latest
#
# - SSH
# ssh `docker inspect -f '{{ .NetworkSettings.IPAddress }}' redmine`

# Base image
FROM     ubuntu:16.04
MAINTAINER Yongbok Kim <ruo91@yongbok.net>

# Change repository
RUN sed -i 's/archive.ubuntu.com/ftp.daumkakao.com/g' /etc/apt/sources.list

# The last package update & install
RUN apt-get update && apt-get install -y curl supervisor openssh-server net-tools aptitude iputils-ping nano \
 ruby-dev imagemagick git build-essential redis-server ruby-redis-rails nginx mariadb-server libmysqlclient-dev libmagickcore-dev pkg-config libmagickwand-dev

# WorkDIR
ENV SRC_DIR /opt
WORKDIR $SRC_DIR

# MariaDB
ENV DB_NAME redmine
ENV DB_USER redmine
ENV DB_PASS redmine
ENV DB_USER_ROOT root
ENV REDMINE_CREATE_DB_SCRIPTS /tmp/redmine_create_db.sh
RUN echo '#!/bin/bash' > $REDMINE_CREATE_DB_SCRIPTS \
 && echo '# Global vars' >> $REDMINE_CREATE_DB_SCRIPTS \
 && echo "export DB_NAME="$DB_NAME"" >> $REDMINE_CREATE_DB_SCRIPTS \
 && echo "export DB_USER="$DB_USER"" >> $REDMINE_CREATE_DB_SCRIPTS \
 && echo "export DB_PASS="$DB_USER"" >> $REDMINE_CREATE_DB_SCRIPTS \
 && echo "export DB_USER_ROOT="$DB_USER_ROOT"" >> $REDMINE_CREATE_DB_SCRIPTS \
 && echo '' >> $REDMINE_CREATE_DB_SCRIPTS \
 && echo '# MariaDB Start' >> $REDMINE_CREATE_DB_SCRIPTS \
 && echo 'service mysql start' >> $REDMINE_CREATE_DB_SCRIPTS \
 && echo '' >> $REDMINE_CREATE_DB_SCRIPTS \
 && echo '# MariaDB root password' >> $REDMINE_CREATE_DB_SCRIPTS \
 && echo "mysqladmin -u $DB_USER_ROOT password '$DB_PASS'" >> $REDMINE_CREATE_DB_SCRIPTS \
 && echo '' >> $REDMINE_CREATE_DB_SCRIPTS \
 && echo '# Create an redmine database & user' >> $REDMINE_CREATE_DB_SCRIPTS \
 && echo "mysql -u root -p$DB_PASS -e 'CREATE DATABASE $DB_NAME CHARACTER SET utf8;'" >> $REDMINE_CREATE_DB_SCRIPTS \
 && echo "mysql -u root -p$DB_PASS -e 'CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY \"$DB_PASS\";'" >> $REDMINE_CREATE_DB_SCRIPTS \
 && echo "mysql -u root -p$DB_PASS -e 'GRANT ALL PRIVILEGES ON $DB_USER.* TO '$DB_USER'@'localhost';'" >> $REDMINE_CREATE_DB_SCRIPTS \
 && echo "mysql -u $DB_USER_ROOT -p$DB_PASS -e 'FLUSH PRIVILEGES;'" >> $REDMINE_CREATE_DB_SCRIPTS \
 && chmod a+x $REDMINE_CREATE_DB_SCRIPTS \
 && $REDMINE_CREATE_DB_SCRIPTS

# Redmine
ENV RAILS_ENV production
ENV REDMINE_HOME $SRC_DIR/redmine
RUN git clone https://github.com/redmine/redmine.git
ADD conf/redmine/database.yml $REDMINE_HOME/config/database.yml
ADD conf/redmine/configuration.yml $REDMINE_HOME/config/configuration.yml
ADD conf/redmine/redis.rb $REDMINE_HOME/config/initializers/redis.rb
ADD conf/redmine/production.rb $REDMINE_HOME/config/environments/production.rb
RUN cd $REDMINE_HOME \
 && useradd -M -s /sbin/nologin redmine \
 && gem install bundler \
 && bundle install --without development test \
 && bundle exec rake generate_secret_token \
 && service mysql start \
 && bundle exec rake db:migrate \
 && bundle exec rake REDMINE_LANG=ko redmine:load_default_data \
 && mkdir -p tmp tmp/pdf public/plugin_assets \
 && chown -R redmine:redmine files log tmp public/plugin_assets \
 && chmod -R 755 files log tmp public/plugin_assets

# Redmine script
ENV REDMINE_START_SCRIPT /bin/redmine.sh
RUN echo '#!/bin/bash' > $REDMINE_START_SCRIPT \
 && echo "export REDMINE_HOME=$REDMINE_HOME" >> $REDMINE_START_SCRIPT \
 && echo 'cd $REDMINE_HOME && bundle exec rails server webrick -e production > /var/log/redmine.log 2>&1 &' >> $REDMINE_START_SCRIPT \
 && chmod a+x $REDMINE_START_SCRIPT

# Nginx (Reverse proxy)
ADD conf/nginx/default /etc/nginx/sites-available/default

# Redis
RUN sed -i 's/bind 127.0.0.1/bind 0.0.0.0/g' /etc/redis/redis.conf \
 && sed -i 's/# unixsocket \/var\/run\/redis\/redis.sock/unixsocket \/tmp\/redis.sock/g' /etc/redis/redis.conf

# Supervisor
RUN mkdir -p /var/log/supervisor
ADD conf/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# SSH
RUN mkdir /var/run/sshd
RUN sed -i '/^#UseLogin/ s:.*:UseLogin yes:' /etc/ssh/sshd_config
RUN sed -i 's/\#AuthorizedKeysFile/AuthorizedKeysFile/g' /etc/ssh/sshd_config
RUN sed -i '/^PermitRootLogin/ s:.*:PermitRootLogin yes:' /etc/ssh/sshd_config

# Root password
RUN echo 'root:redmine' |chpasswd

# Port
EXPOSE 22 80

# Daemon
CMD ["/usr/bin/supervisord"]
