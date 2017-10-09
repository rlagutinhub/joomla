#! /bin/sh

set -e
set -x

# system
yum -y --setopt=tsflags=nodocs install \
bash-completion \
less \
wget \
curl \
pigz \
which \
tar \
gzip \
bzip2 \
zip \
unzip \
findutils \
util-linux \
net-tools \
iproute \
bind-utils \
at \
cronie \
crontabs \
acl \
attr \
make \
lsof \
telnet \
tree \
nmap \
tcpdump \
mailx \
htop \
mc \
vim-minimal vim-enhanced

# pip
yum -y --setopt=tsflags=nodocs install python-setuptools python-pip

# mysql, mysqldump
yum -y --setopt=tsflags=nodocs install Percona-Server-client-57

# nginx
yum -y --setopt=tsflags=nodocs install nginx

# php5
yum -y --setopt=tsflags=nodocs install \
php \
php-common \
php-cli \
php-fpm \
php-mysql \
php-cgi \
php-curl \
php-gd \
php-json \
php-mbstring \
php-mcrypt \
php-readline \
php-xml

