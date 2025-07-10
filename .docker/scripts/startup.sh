#!/bin/sh

sed -i "s,LISTEN_PORT,$PORT,g" /etc/nginx/nginx.conf

#Start crontab
crond start

#run migrate
php artisan migrate --force > storage/logs/deploy.log 2>&1
