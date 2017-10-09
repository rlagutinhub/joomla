#! /bin/sh

set -e
set -x

# epel repo
yum -y --setopt=tsflags=nodocs install epel-release

# percona
yum -y --setopt=tsflags=nodocs install http://www.percona.com/downloads/percona-release/redhat/0.1-4/percona-release-0.1-4.noarch.rpm

# nginx repo
cat <<EOF > /etc/yum.repos.d/nginx.repo
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/centos/7/x86_64/
gpgcheck=0
enabled=1
EOF
