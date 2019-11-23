#!/bin/bash
# Description: install LNMP, Composer and Redis
# Author: tlanyan<https://tlanyan.me>

function checkSystem()
{
    result=$(id | awk '{print $1}')
    if [ $result != "uid=0(root)" ]; then
        echo "action must be carried out by root!"
        exit 1
    fi

    if [ ! -f /etc/centos-release ];then
        echo false
        return
    fi
    
    result=`cat /etc/centos-release|grep "CentOS Linux release 7"`
    if [ "$result" = "" ]; then
        echo false
    fi
    echo true
}

function installNginx()
{
    yum install epel-release
    yum install -y nginx
    systemctl enable nginx.service
}

function installPHP()
{
    yum install epel-release
    yum install -y https://mirrors.tuna.tsinghua.edu.cn/remi/enterprise/remi-release-7.rpm
    rm -rf /etc/yum.repos.d/remi-php54.repo
    rm -rf /etc/yum.repos.d/remi-php70.repo
    rm -rf /etc/yum.repos.d/remi-php71.repo
	sed -i '0,/enabled=0/{s/enabled=0/enabled=1/}' /etc/yum.repos.d/remi-php72.repo
    yum install -y php-cli php-fpm php-gd php-mbstring php-mysqlnd php-pdo php-opcache php-xml php-pecl-zip
    systemctl enable php-fpm.service
}

function installComposer()
{
    wget https://getcomposer.org/installer
    php installer
    rm -rf installer
    mv composer.phar /usr/local/bin/composer
}

function installMariaDB()
{
    echo '# MariaDB 10.4 CentOS repository list - created 2019-11-23 15:00 UTC
# http://downloads.mariadb.org/mariadb/repositories/
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.4/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1' >> /etc/yum.repos.d/mariadb.repo
    yum install -y MariaDB-server MariaDB-client
    systemctl enable mariadb.service
}


function installRedis()
{
    yum install -y redis
    systemctl enable redis.service
}

result=$(checkSystem)
if [ "$result" != "true" ]; then
    echo "scripts only tested on centos 7!"
    exit 1
fi
echo -n "system version :  "
cat /etc/centos-release

yum update -y
installNginx

installPHP

installComposer

installMariaDB

installRedis
