# vendor="Lagutin R.A."
# maintainer="Lagutin R.A. <rlagutin@mta4.ru>"
# name="Joomla CMS autoconfig."
# description="Joomla CMS autoconfig with NGINX, PHP-FPM via supervisord."
# version="v.1-prod."
# release-date="201710091020"

# ---------------------------------------------------------------------------

# Provide access to Joomla data on HTTP Server
# Important: For this HTTP Server should be resolve DNS Records into container or use ip!

# Backup www
# tar cvzfp portal.tgz -C /var/www/portal.local/ .

# Backup sql
# mysqldump -u root -h localhost -p123456 --default-character-set=utf8 --max-allowed-packet=1G --routines --events --triggers "joomla" | gzip -9 > ~/joomla.$(date +"%Y%m%d%H%M").sql.gz

# yum install nginx
# systemctl enable nginx; systemctl start nginx

# scp data.www.20171008.tgz <HTTP Server>:/usr/share/nginx/html/
# scp data.sql.20171008.sql.gz <HTTP Server>:/usr/share/nginx/html/

# ---------------------------------------------------------------------------

# Docker Image:
# docker build -t rlagutinhub/joomla:201710091020 .

# Docker network:
# docker network create -d bridge joomla_net-prod

# Docker volume:
# docker volume create joomla_data-www
# docker volume create joomla_data-sql

# Docker container joomla-db (Percona DB):
# docker run -dit \
#  -e "MYSQL_ROOT_PASSWORD=1qaz@WSX" \
#  -e "MYSQL_DATABASE=joomla" \
#  -e "MYSQL_USER=joomla" \
#  -e "MYSQL_PASSWORD=1qaz@WSX" \
#  --network=joomla_net-prod \
#  -v joomla_data-sql:/var/lib/mysql \
#  --name joomla-db \
#  percona:latest

# Docker container joomla-app:
# docker run -dit \
#  -e "PORTAL_VHOST_DIR=/var/www/portal.local" \
#  -e "PORTAL_VHOST_NAME=portal.example.com" \
#  -e "PORTAL_MYSQL_HOSTNAME=joomla-db" \
#  -e "PORTAL_MYSQL_USERNAME=joomla" \
#  -e "PORTAL_MYSQL_PASSWORD=1qaz@WSX" \
#  -e "PORTAL_MYSQL_DBNAME=joomla" \
#  -e "URL_WWW_DATA=http://192.168.1.1/data.www.20171008.tgz" \
#  -e "URL_SQL_DATA=http://192.168.1.1/data.sql.20171008.sql.gz" \
#  --memory="2048m" --cpus=1 \
#  --network=joomla_net-prod -p 80:80 \
#  -v joomla_data-www:/var/www/ \
#  --name joomla-app \
#  rlagutinhub/joomla:201710091020

# Other:
# docker ps -a
# docker container ls -a
# docker image ls -a
# docker exec -it joomla-db bash (After complete work input: exit)
# docker exec -it joomla-app bash (After complete work input: exit)
# docker logs joomla-db
# docker logs joomla-app
# docker container stop joomla-db
# docker container stop joomla-app
# docker container rm joomla-db
# docker container rm joomla-app
# docker network rm joomla_net-prod
# docker volume rm joomla_data-www
# docker volume rm joomla_data-sql
# docker image rm rlagutinhub/joomla:201710091020

FROM centos:latest
# FROM fedora:latest

LABEL rlagutinhub.community.vendor="Lagutin R.A." \
	rlagutinhub.community.maintainer="Lagutin R.A. <rlagutin@mta4.ru>" \
	rlagutinhub.community.name="Joomla CMS autoconfig." \
	rlagutinhub.community.description="Joomla CMS autoconfig with NGINX, PHP-FPM via supervisord." \
	rlagutinhub.community.version="v.1-prod." \
	rlagutinhub.community.release-date="201710091020"

COPY build /tmp/build
# COPY data /tmp/data

RUN chmod -x /tmp/build/supervisord.conf && mv -f /tmp/build/supervisord.conf /etc/supervisord.conf && \
	chmod +x /tmp/build/* && mv -f /tmp/build/bash-color.sh /etc/profile.d/bash-color.sh && mv -f /tmp/build/docker-entrypoint.sh /etc/docker-entrypoint.sh && \
	for script in /tmp/build/*.sh; do sh $script; done && \
	rm -rf /tmp/build

# EXPOSE 80 443
EXPOSE 80

ENTRYPOINT ["/etc/docker-entrypoint.sh"]
CMD ["supervisord", "-c", "/etc/supervisord.conf"]

