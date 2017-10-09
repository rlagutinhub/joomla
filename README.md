## Docker: joomla

Compiled Docker image: https://hub.docker.com/r/rlagutinhub/joomla/

-	Joomla CMS autoconfig with NGINX, PHP-FPM via supervisord.
-	Base image centos:latest

#### Manual install

```console
git clone https://github.com/rlagutinhub/joomla.git
cd joomla
```

Docker Image:

```console
docker build -t rlagutinhub/joomla:201710091020 .
```

Docker network:

```console
docker network create -d bridge joomla_net-prod
```

Docker volume:

```console
docker volume create joomla_data-www
docker volume create joomla_data-sql
```

Docker container joomla-db (Percona DB):

```console
docker run -dit \
 -e "MYSQL_ROOT_PASSWORD=1qaz@WSX" \
 -e "MYSQL_DATABASE=joomla" \
 -e "MYSQL_USER=joomla" \
 -e "MYSQL_PASSWORD=1qaz@WSX" \
 --network=joomla_net-prod \
 -v joomla_data-sql:/var/lib/mysql \
 --name joomla-db \
 percona:latest
```

Docker container joomla-app (Joomla CMS):

```console
docker run -dit \
 -e "PORTAL_VHOST_DIR=/var/www/portal.local" \
 -e "PORTAL_VHOST_NAME=portal.example.com" \
 -e "PORTAL_MYSQL_HOSTNAME=joomla-db" \
 -e "PORTAL_MYSQL_USERNAME=joomla" \
 -e "PORTAL_MYSQL_PASSWORD=1qaz@WSX" \
 -e "PORTAL_MYSQL_DBNAME=joomla" \
 -e "URL_WWW_DATA=http://192.168.1.1/data.www.20171008.tgz" \
 -e "URL_SQL_DATA=http://192.168.1.1/data.sql.20171008.sql.gz" \
 --memory="2048m" --cpus=1 \
 --network=joomla_net-prod -p 80:80 \
 -v joomla_data-www:/var/www/ \
 --name joomla-app \
 rlagutinhub/joomla:201710091020
```

Other:

```console
docker ps -a
docker container ls -a
docker image ls -a
docker exec -it joomla-db bash (After complete work input: exit)
docker exec -it joomla-app bash (After complete work input: exit)
docker logs joomla-db
docker logs joomla-app
docker container stop joomla-db
docker container stop joomla-app
docker container rm joomla-db
docker container rm joomla-app
docker network rm joomla_net-prod
docker volume rm joomla_data-www
docker volume rm joomla_data-sql
docker image rm rlagutinhub/joomla:201710091020
```

#### Auto install (docker-compose)

```console
pip install -U docker-compose
git clone https://github.com/rlagutinhub/joomla.git
cd joomla
```

```console
./start.sh
./stop.sh
./status.sh
./rm.sh
./check-conf-yml.sh
```

Connect to container:

```console
./connect.sh
```
