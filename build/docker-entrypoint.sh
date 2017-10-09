#!/bin/bash

set -e
set -x

# VARIABLES

KEEP_DATA_FLAG=".keep_data"
KEEP_CONF_FLAG=".keep_conf"

PORTAL_VHOST_DIR=${PORTAL_VHOST_DIR:-"/var/www/portal.local"}
PORTAL_VHOST_NAME=${PORTAL_VHOST_NAME:-"portal.example.com"}

PORTAL_MYSQL_HOSTNAME=${PORTAL_MYSQL_HOSTNAME:-"joomla-db"}
PORTAL_MYSQL_USERNAME=${PORTAL_MYSQL_USERNAME:-"joomla"}
PORTAL_MYSQL_PASSWORD=${PORTAL_MYSQL_PASSWORD:-"1qaz@WSX"}
PORTAL_MYSQL_DBNAME=${PORTAL_MYSQL_DBNAME:-"joomla"}

URL_WWW_DATA=${URL_WWW_DATA:-"empty"}
URL_SQL_DATA=${URL_SQL_DATA:-"empty"}

PORTAL_DATA_DIR=/tmp/data
PORTAL_VHOST_DATA_FILE=/tmp/data/data.www.20171008.tgz
PORTAL_MYSQL_DATA_FILE=/tmp/data/data.sql.20171008.sql.gz

SYSTEM_PHP_INI=/etc/php.ini
SYSTEM_PHP_FPM_CONF=/etc/php-fpm.conf
SYSTEM_PHP_FPM_WWW_CONF=/etc/php-fpm.d/www.conf
SYSTEM_NGINX_CONF=/etc/nginx/nginx.conf
SYSTEM_NGINX_VHOST_CONF=/etc/nginx/conf.d/$PORTAL_VHOST_NAME.conf
SYSTEM_JOOMLA_CONF=$PORTAL_VHOST_DIR/configuration.php
SYSTEM_TMP_DATA=/tmp/data

# FUNCTION

# $1 - the file in which to do the search/replace
function COMMENT_SED() {
    sed -i 's/^/#&/g' $1
}

# $1 - the setting/property to set
# $2 - the new value
# $3 - the file in which to do the search/replace

function SET_SED() {
    sed -i s~"\#\? \?$1 \?=.*"~"$1 = $2"~g "$3"
}

# $1 - the text to search for
# $2 - the replacement text
# $3 - the file in which to do the search/replace
function REPLACE_SED() {
    sed -i "s/$(echo $1 | sed -e 's/\([[\/.*]\|\]\)/\\&/g')/$(echo $2 | sed -e 's/[\/&]/\\&/g')/g" $3
}

# $1 - the text to search for
# $2 - the replacement text
# $3 - the file in which to do the search/replace
function APPEND_SED() {
    sed -i "/$(echo $1 | sed -e 's/\([[\/.*]\|\]\)/\\&/g')/a $(echo $2 | sed -e 's/[\/&]/\\&/g')" $3
}

# $1 = $PORTAL_MYSQL_HOSTNAME
# $2 = $PORTAL_MYSQL_USERNAME
# $3 = $PORTAL_MYSQL_PASSWORD
function CHECK_MYSQL() {

    local CHECKFILE=/tmp/check.mysql
    eval $(MYSQL_PWD=$3 mysql -u $2 -h $1 -s -N -e "exit" > $CHECKFILE 2>&1)

}

# $1 = $PORTAL_MYSQL_HOSTNAME
# $2 = $PORTAL_MYSQL_USERNAME
# $3 = $PORTAL_MYSQL_PASSWORD
function CHECK_MYSQL_PARS() {
# https://docs.docker.com/compose/startup-order/

    local CHECKFILE=/tmp/check.mysql

    local COUNT=0
    local LIMIT=300 # timeout 5 min

    CHECK_MYSQL $1 $2 $3

    while [ -s $CHECKFILE ]; do

        echo "MYSQL is down"
        sleep 1

        if [ $COUNT -eq $LIMIT ]; then
            echo "Error: Stop deploy - Mysql container not running."; exit 1

        else
            COUNT=$(( COUNT +1 ))
            CHECK_MYSQL $1 $2 $3
        fi

    done

    echo "MYSQL is up"

}

# $1 = $URL_WWW_DATA
# $2 = $URL_SQL_DATA
# $3 = $PORTAL_DATA_DIR
# $4 = $PORTAL_VHOST_DATA_FILE
# $5 = $PORTAL_MYSQL_DATA_FILE
function GET_DATA() {

    if [ "$1" == "empty" ] || [ "$2" == "empty" ]; then

        echo "Error: Stop deploy - URL_WWW_DATA, URL_SQL_DATA not defined."; exit 1

    else

        mkdir -p $3

        echo "Downloading $1 to $4"
        curl -fsL $1 -o $4

        echo "Downloading $2 to $5"
        curl -fsL $2 -o $5

    fi

}

# $1 = $PORTAL_VHOST_DATA_FILE
# $2 = $PORTAL_VHOST_DIR
function RESTORE_WWW() {

    if [ ! -f $1 ]; then echo "Error: Stop deploy - PORTAL_VHOST_DATA_FILE not found."; exit 1; fi
    if [ -d $2 ]; then mv $2 $2.$(date +%Y-%m-%d.%H-%M-%S.%N).old; fi

    mkdir -p $2; $(which tar) xvzf $1 -C $2

}

# $1 = $PORTAL_MYSQL_HOSTNAME
# $2 = $PORTAL_MYSQL_USERNAME
# $3 = $PORTAL_MYSQL_PASSWORD
# $4 = $PORTAL_MYSQL_DBNAME
# $5 = $PORTAL_MYSQL_DATA_FILE
function RESTORE_SQL() {

    local DBNAME=$($(which mysql) -u ${2} -h ${1} -p${3} --skip-column-names -e "SHOW DATABASES LIKE '${4}'" 2> /dev/null)

    if [ ! -f $5 ]; then echo "Error: Stop deploy - PORTAL_MYSQL_DATA_FILE not found."; exit 1; fi

    if [ "$DBNAME" == "$4" ]; then

        # mysqldump -u root -h localhost -p123456 --default-character-set=utf8 --max-allowed-packet=1G --routines --events --triggers "joomla" | gzip -9 > ~/joomla.$(date +"%Y%m%d%H%M").sql.gz
        # gunzip < ~/joomla.201710081107.sql.gz | mysql -u root -h localhost -p1qaz@WSX "joomla"
        gunzip < $5 | mysql -u $2 -h $1 -p$3 $4

    fi

}

# $1 = $SYSTEM_PHP_INI
function PHP_SETUP() {

    if [ -f $1 ]; then

        cp -p $1 $1.$(date +%Y-%m-%d.%H-%M-%S.%N).orig
        SET_SED "post_max_size" "20M" $1
        REPLACE_SED ";upload_tmp_dir =" "upload_tmp_dir =" $1
        SET_SED "upload_tmp_dir" "/var/tmp" $1
        SET_SED "upload_max_filesize" "10M" $1
        SET_SED "session.gc_probability" "0" $1

    fi

}

# $1 = $SYSTEM_PHP_FPM_CONF
function PHP-FPM_SETUP() {

    if [ -f $1 ]; then

        cp -p $1 $1.$(date +%Y-%m-%d.%H-%M-%S.%N).orig
        SET_SED "daemonize" "yes" $1

    fi

}

# $1 = $SYSTEM_PHP_FPM_WWW_CONF
function PHP-FPM_WWW_CONF_SETUP() {

    if [ -f $1 ]; then

        cp -p $1 $1.$(date +%Y-%m-%d.%H-%M-%S.%N).orig
        REPLACE_SED "listen.allowed_clients = 127.0.0.1" ";listen.allowed_clients = 127.0.0.1" $1
        REPLACE_SED ";listen.owner = nobody" "listen.owner = nobody" $1
        REPLACE_SED ";listen.group = nobody" "listen.group = nobody" $1
        SET_SED "listen.owner" "nginx" $1
        SET_SED "listen.group" "nginx" $1
        SET_SED "user" "nginx" $1
        SET_SED "group" "nginx" $1
        SET_SED "pm.max_children" "5" $1
        SET_SED "pm.start_servers" "2" $1
        SET_SED "pm.min_spare_servers" "1" $1
        SET_SED "pm.max_spare_servers" "3" $1

    fi

}

# $1 = $SYSTEM_NGINX_CONF
function NGINX_SETUP() {

    if [ -f $1 ]; then

        cp -p $1 $1.$(date +%Y-%m-%d.%H-%M-%S.%N).orig

cat <<EOF > $1
user nginx;
worker_processes 2;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events {
    worker_connections 1024;
    # multi_accept on;
}

http {

    ##
    # Basic Settings
    ##

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 100m;
    # server_tokens off;

    # server_names_hash_bucket_size 64;
    # server_name_in_redirect off;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    ##
    # Logging Settings
    ##

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                  '$status $body_bytes_sent "$http_referer" '
                  '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    ##
    # Gzip Settings
    ##

    gzip on;
    gzip_disable "msie6";

    gzip_http_version 1.1;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_min_length 1100;
    gzip_buffers 4 8k;
    gzip_types text/plain application/xhtml+xml text/css application/xml application/xml+rss text/javascript application/javascript application/x-javascript;

    ##
    # nginx-naxsi config
    ##
    # Uncomment it if you installed nginx-naxsi
    ##

    #include /etc/nginx/naxsi_core.rules;

    ##
    # nginx-passenger config
    ##
    # Uncomment it if you installed nginx-passenger
    ##

    #passenger_root /usr;
    #passenger_ruby /usr/bin/ruby;

    ##
    # Virtual Host Configs
    ##

    include /etc/nginx/conf.d/*.conf;
    # include /etc/nginx/sites-enabled/*;
}


#mail {
#   # See sample authentication script at:
#   # http://wiki.nginx.org/ImapAuthenticateWithApachePhpScript
#
#   # auth_http localhost/auth.php;
#   # pop3_capabilities "TOP" "USER";
#   # imap_capabilities "IMAP4rev1" "UIDPLUS";
#
#   server {
#       listen     localhost:110;
#       protocol   pop3;
#       proxy      on;
#   }
#
#   server {
#       listen     localhost:143;
#       protocol   imap;
#       proxy      on;
#   }
#}

EOF

    fi

}

# $1 = $SYSTEM_NGINX_VHOST_CONF
# $2 = $PORTAL_VHOST_DIR
# $3 = $PORTAL_VHOST_NAME
function NGINX_VHOST_SETUP() {

    local NGINX_VHOST_DEFAULT=/etc/nginx/conf.d/default.conf

    if [ -f $NGINX_VHOST_DEFAULT ]; then

        mv $NGINX_VHOST_DEFAULT $NGINX_VHOST_DEFAULT.$(date +%Y-%m-%d.%H-%M-%S.%N).orig

    fi

    if [ -f $1 ]; then

        cp -p $1 $1.$(date +%Y-%m-%d.%H-%M-%S.%N).orig

    fi

cat <<EOF > $1
server {
    listen 80 default_server;

        root $2;
        server_name $3;
        access_log /var/log/nginx/$3.access.log;
        error_log /var/log/nginx/$3.error.log;

        index index.php;
    autoindex on;

    location / {
        # /index.php?\$args;
        try_files \$uri \$uri/ /index.php?q=\$uri&\$args;
    }

        location ~* /(images|cache|media|logs|tmp)/.*\.(php|pl|py|jsp|asp|sh|cgi)\$ {
                return 403;
                error_page 403 /403_error.html;
        }

        location ~ \.php\$ {
            fastcgi_pass  127.0.0.1:9000;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param   PATH_INFO       \$fastcgi_script_name;

            include fastcgi_params;
        fastcgi_param  QUERY_STRING     \$query_string;
        fastcgi_param  REQUEST_METHOD   \$request_method;
        fastcgi_param  CONTENT_TYPE     \$content_type;
        fastcgi_param  CONTENT_LENGTH   \$content_length;

        fastcgi_intercept_errors        on;
        fastcgi_ignore_client_abort     off;
        fastcgi_connect_timeout 60;
        fastcgi_send_timeout 180;
        fastcgi_read_timeout 180;
        fastcgi_buffer_size 128k;
        fastcgi_buffers 4 256k;
        fastcgi_busy_buffers_size 256k;
        fastcgi_temp_file_write_size 256k;
        }

        # caching of files 
        location ~* \.(ico|pdf|flv)\$ {
                expires 1y;
        }

        location ~* \.(js|css|png|jpg|jpeg|gif|swf|xml|txt)\$ {
                expires 14d;
        }

}

EOF

}

# $1 = $SYSTEM_JOOMLA_CONF
# $2 = $PORTAL_MYSQL_HOSTNAME
# $3 = $PORTAL_MYSQL_USERNAME
# $4 = $PORTAL_MYSQL_PASSWORD
# $5 = $PORTAL_MYSQL_DBNAME
function JOOMLA_SETUP() {

    if [ -f $1 ]; then

        cp -p $1 $1.$(date +%Y-%m-%d.%H-%M-%S.%N).orig
        SET_SED "public \$host" "'$2';" $1
        SET_SED "public \$user" "'$3';" $1
        SET_SED "public \$password" "'$4';" $1
        SET_SED "public \$db" "'$5';" $1

    fi

}

# $1 = $PORTAL_VHOST_DIR
function PERM_SETUP() {

    chown -R nginx:nginx $1; chmod -R 0750 $1

}

# $1 = $SYSTEM_TMP_DATA
function DEL_TMP_DATA() {

    if [ -d $1 ]; then

        rm -rf $1

    fi

}

function CONFIGURE_DATA() {

    echo 'Configuring joomla data...'

    GET_DATA $URL_WWW_DATA $URL_SQL_DATA $PORTAL_DATA_DIR $PORTAL_VHOST_DATA_FILE $PORTAL_MYSQL_DATA_FILE
    RESTORE_WWW $PORTAL_VHOST_DATA_FILE $PORTAL_VHOST_DIR
    RESTORE_SQL $PORTAL_MYSQL_HOSTNAME $PORTAL_MYSQL_USERNAME $PORTAL_MYSQL_PASSWORD $PORTAL_MYSQL_DBNAME $PORTAL_MYSQL_DATA_FILE
    JOOMLA_SETUP $SYSTEM_JOOMLA_CONF $PORTAL_MYSQL_HOSTNAME $PORTAL_MYSQL_USERNAME $PORTAL_MYSQL_PASSWORD $PORTAL_MYSQL_DBNAME
    PERM_SETUP $PORTAL_VHOST_DIR
    DEL_TMP_DATA $SYSTEM_TMP_DATA

}

function CONFIGURE_CONF() {

    echo 'Configuring joomla conf...'

    PHP_SETUP $SYSTEM_PHP_INI
    PHP-FPM_SETUP $SYSTEM_PHP_FPM_CONF
    PHP-FPM_WWW_CONF_SETUP $SYSTEM_PHP_FPM_WWW_CONF
    NGINX_SETUP $SYSTEM_NGINX_CONF
    NGINX_VHOST_SETUP $SYSTEM_NGINX_VHOST_CONF $PORTAL_VHOST_DIR $PORTAL_VHOST_NAME

}

# $1 = $PORTAL_VHOST_DIR
# $2 = $KEEP_DATA_FLAG
function FIRST_START_DATA() {

    CONFIGURE_DATA; touch $1/$2

}

# $1 = $KEEP_CONF_FLAG
function FIRST_START_CONF() {

    CONFIGURE_CONF; touch /etc/$1

}

# MAIN
# https://github.com/docker-library/official-images#consistency
# https://docs.docker.com/engine/userguide/eng-image/dockerfile_best-practices/#entrypoint
# https://github.com/CentOS/CentOS-Dockerfiles/tree/master/httpd/centos7

if [ "${1:0:1}" = '-' ]; then
    set -- supervisord "$@"
fi

if [ "$1" = 'supervisord' ]; then

    CHECK_MYSQL_PARS $PORTAL_MYSQL_HOSTNAME $PORTAL_MYSQL_USERNAME $PORTAL_MYSQL_PASSWORD

    if [ ! -f $PORTAL_VHOST_DIR/$KEEP_DATA_FLAG ]; then
        FIRST_START_DATA $PORTAL_VHOST_DIR $KEEP_DATA_FLAG
    fi

    if [ ! -f /etc/$KEEP_CONF_FLAG ]; then
        FIRST_START_CONF $KEEP_CONF_FLAG
    fi

    shift
    set -- "$(which supervisord)" "$@"

fi

exec "$@"


