#!/usr/bin/env bash
apt-get update -q
apt-get upgrade -y
apt-get install -y git nginx
rm /etc/nginx/sites-enabled/default 
cat > /etc/nginx/conf.d/webapp.conf <<EOF
server {
    listen 8080;
    server_name _;
    root /var/webapp;
}
EOF
mkdir /var/webapp
cp /tmp/index.html /var/webapp/
HOST=`hostname`
sed -i "s#everybody#___MYUSER___ at $HOST#" /var/webapp/index.html
systemctl restart nginx
