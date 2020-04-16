#!/bin/bash
# centos7/8 WordPress一键安装脚本
# Author: tlanyan
# link: https://tlanyan.me

red='\033[0;31m'
plain='\033[0m'

function checkSystem()
{
    result=$(id | awk '{print $1}')
    if [ $result != "uid=0(root)" ]; then
        echo "请以root身份执行该脚本"
        exit 1
    fi

    if [ ! -f /etc/centos-release ];then
        echo "系统不是CentOS"
        exit 1
    fi
    
    result=`cat /etc/centos-release|grep -oE "[0-9.]+"`
    main=${result%%.*}
    if [ $main -lt 7 ]; then
        echo "不受支持的CentOS版本"
        exit 1
    fi
}

function collect()
{
    while true
    do
        read -p "请输入您的域名：" domain
        if [ ! -z "$domain" ]; then
            break
        fi
    done
}

function preInstall()
{
    yum install -y epel-release
    yum install -y telnet curl wget rsync htop python3-pip python3-devel iptraf-ng vim tar
    pip3 install --upgrade pip
    yum update -y

    if [ $main -eq 7 ]; then
        yum -y remove git*
        yum -y install  https://centos7.iuscommunity.org/ius-release.rpm
        yum -y install  git2u-all
    else
        yum install -y git
    fi


    wget -O ~/vim.tar.gz https://github.com/tlanyan/scripts/raw/master/files/vim.tar.gz
    if [ -f vim.tar.gz ]; then
        tar -zxf vim.tar.gz
        rm -rf vim.tar.gz
    fi

    echo 'export EDITOR=vim' >> ~/.bashrc
}

function installNginx()
{
    yum install -y nginx
    systemctl enable nginx
}

function installPHP()
{
    rpm -iUh https://mirrors.tuna.tsinghua.edu.cn/remi/enterprise/remi-release-${main}.rpm
    if [ $main -eq 7 ]; then
	    sed -i '0,/enabled=0/{s/enabled=0/enabled=1/}' /etc/yum.repos.d/remi-php74.repo
    else
        sed -i '0,/enabled=0/{s/enabled=0/enabled=1/}' /etc/yum.repos.d/remi.repo
        dnf module install -y php:remi-7.4
    fi
    yum install -y php-cli php-fpm php-bcmath php-gd php-mbstring php-mysqlnd php-pdo php-opcache php-xml php-pecl-zip
    systemctl enable php-fpm.service
}

function installMysql()
{
    echo "# MariaDB 10.4 CentOS repository list
# http://downloads.mariadb.org/mariadb/repositories/
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.4/centos${main}-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1" >> /etc/yum.repos.d/mariadb.repo
    if [ $main -eq 8 ]; then
        echo "module_hotfixes=1" >>  /etc/yum.repos.d/mariadb.repo
    fi

    yum install -y MariaDB-server
    systemctl enable mariadb.service
}

function installRedis()
{
    yum install -y redis
    systemctl enable redis
}

function installWordPress()
{
    yum install -y wget
    mkdir -p /var/www;
    wget https://cn.wordpress.org/latest-zh_CN.tar.gz
    if [ ! -f latest-zh_CN.tar.gz ]; then
        wget https://tlanyan.me/latest-zh_CN.tar.gz
        if [ ! -f latest-zh_CN.tar.gz ]; then
            echo "下载WordPress失败，请稍后重试"
            exit 1
        fi
    fi
    tar -zxf latest-zh_CN.tar.gz
    mv wordpress /var/www/${domain}
    rm -rf latest-zh_CN.tar.gz
}

function config()
{
    # config mariadb
    systemctl start mariadb
    dbname="wordpress"
    dbuser="wordpress"
    dbpass=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1`
    mysql -uroot <<EOF
DELETE FROM mysql.user WHERE User='';
CREATE DATABASE $dbname default charset utf8mb4;
CREATE USER ${dbuser}@'%' IDENTIFIED BY '${dbpass}';
GRANT ALL PRIVILEGES ON ${dbname}.* to ${dbuser}@'%';
FLUSH PRIVILEGES;
EOF

    #config php
    sed -i 's/expose_php = On/expose_php = Off/' /etc/php.ini
    line=`cat -n /etc/php.ini | grep 'date.timezone' | tail -n1 | awk '{print $1}'`
    sed -i "${line}a date.timezone = Asia/Shanghai" /etc/php.ini
    sed -i 's/;opcache.revalidate_freq=2/opcache.revalidate_freq=30/' /etc/php.d/10-opcache.ini
    if [ $main -eq 7 ]; then
        sed -i 's/listen = 127.0.0.1:9000/listen = \/run\/php-fpm\/www.sock/' /etc/php-fpm.d/www.conf
    fi
    line=`cat -n /etc/php-fpm.d/www.conf | grep 'listen.mode' | tail -n1 | awk '{print $1}'`
    sed -i "${line}a listen.mode=0666" /etc/php-fpm.d/www.conf
    sed -i 's/php_value\[session.save_handler\] = files/php_value\[session.save_handler\] = redis/' /etc/php-fpm.d/www.conf
    sed -i 's/php_value\[session.save_path\]    = \/var\/lib\/php\/session/php_value\[session.save_path\]    = "tcp:\/\/127.0.0.1:6379"/' /etc/php-fpm.d/www.conf

    # config wordpress
    cd /var/www/$domain
    cp wp-config-sample.php wp-config.php
    sed -i "s/database_name_here/$dbname/g" wp-config.php
    sed -i "s/username_here/$dbuser/g" wp-config.php
    sed -i "s/password_here/$dbpass/g" wp-config.php
    sed -i "s/utf8/utf8mb4/g" wp-config.php
    perl -i -pe'
  BEGIN {
    @chars = ("a" .. "z", "A" .. "Z", 0 .. 9);
    push @chars, split //, "!@#$%^&*()-_ []{}<>~\`+=,.;:/?|";
    sub salt { join "", map $chars[ rand @chars ], 1 .. 64 }
  }
  s/put your unique phrase here/salt()/ge
' wp-config.php
    chown -R apache:apache /var/www/$domain

    # config nginx
    mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
    cat > /etc/nginx/nginx.conf<<-EOF
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# Load dynamic modules. See /usr/share/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for" "\$request_time"';

    access_log  /var/log/nginx/access.log  main buffer=32k flush=30s;

    server_tokens       off;
    client_max_body_size 100m;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
    ssl_ecdh_curve secp384r1; 
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;
    ssl_stapling on; # Requires nginx >= 1.3.7
    ssl_stapling_verify on; # Requires nginx => 1.3.7
    add_header Strict-Transport-Security "max-age=63072000; preload";
    #add_header X-Frame-Options DENY;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";

    fastcgi_cache_path /dev/shm/wordpress levels=1:2 keys_zone=wordpress:30m inactive=30m use_temp_path=off;
    fastcgi_cache_key \$request_method\$scheme\$host\$request_uri;
    fastcgi_cache_lock on;
    fastcgi_cache_use_stale error timeout invalid_header updating http_500;
    fastcgi_cache_valid 200 301 302 30m;
    fastcgi_cache_valid 404 10m;
    fastcgi_ignore_headers Expires Set-Cookie Vary;

    gzip on;
    gzip_min_length  2k;
    gzip_buffers     4 16k;
    gzip_comp_level 4;
    gzip_types
        text/css
        text/plain
        text/javascript
        application/javascript
        application/json
        application/x-javascript
        application/xml
        application/xml+rss
        application/xhtml+xml
        application/x-font-ttf
        application/x-font-opentype
        application/vnd.ms-fontobject
        image/svg+xml
        application/rss+xml
        application/atom_xml
        image/jpeg
        image/gif
        image/png
        image/icon
        image/bmp
        image/jpg;
    gzip_vary on;

    # Load modular configuration files from the /etc/nginx/conf.d directory.
    # See http://nginx.org/en/docs/ngx_core_module.html#include
    # for more information.
    include /etc/nginx/conf.d/*.conf;
}
EOF
    cat > /etc/nginx/conf.d/${domain}.conf<<-EOF
server {
    listen 80;
    server_name ${domain};
    
    charset utf-8;
    
    set \$host_path "/var/www/${domain}";
    access_log  /var/log/nginx/${domain}.access.log  main buffer=32k flush=30s;
    error_log /var/log/nginx/${domain}.error.log;

    root   \$host_path;

    set \$skip_cache 0;
    if (\$query_string != "") {
        set \$skip_cache 1;
    }
    if (\$request_uri ~* "/wp-admin/|/xmlrpc.php|wp-.*.php|/feed/|sitemap(_index)?.xml") {
        set \$skip_cache 1;
    }
    # 登录用户或发表评论者
    if (\$http_cookie ~* "comment_author|wordpress_[a-f0-9]+|wp-postpass|wordpress_no_cache|wordpress_logged_in") {
        set \$skip_cache 1;
    }

    location = / {
        index  index.php index.html;
        try_files /index.php?\$args /index.php?\$args;
    }

    location / {
        index  index.php index.html;
        try_files \$uri \$uri/ /index.php?\$args;
    }
    location ~ ^/\.user\.ini {
            deny all;
    }

    location ~ \.php\$ {
        try_files \$uri =404;
        fastcgi_index index.php;
        fastcgi_cache wordpress;
        fastcgi_cache_bypass \$skip_cache;
        fastcgi_no_cache \$skip_cache;
        fastcgi_pass unix:/run/php-fpm/www.sock;
        include fastcgi_params;
        fastcgi_param  SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
    }
    location ~ \.(js|css|png|jpg|jpeg|gif|ico|swf|webp|pdf|txt|doc|docx|xls|xlsx|ppt|pptx|mov|fla|zip|rar)\$ {
        expires max;
        access_log off;
        try_files \$uri =404;
    }
}
EOF

    #disable selinux
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
        setenforce 0
    fi

    # firewall
    systemctl status firewalld > /dev/null 2>&1
    if [ $? -eq 0 ];then
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        firewall-cmd --reload
    fi

    # restart service
    systemctl restart php-fpm mariadb nginx redis
}

function installBBR()
{
    result=$(lsmod | grep bbr)
    if [ "$result" != "" ]; then
        echo BBR模块已安装
        bbr=true
        return
    fi
    res=`hostnamectl | grep -i openvz`
    if [ "$res" != "" ]; then
        echo "openvz,跳过安装"
        bbr=true
        return
    fi
    
    if [ $main -eq 8 ]; then
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
        sysctl -p
        bbr=true
        return
    fi

    echo 安装BBR模块...
    rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
    rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-4.el7.elrepo.noarch.rpm
    yum --enablerepo=elrepo-kernel install kernel-ml -y
    grub2-set-default 0
    echo "tcp_bbr" >> /etc/modules-load.d/modules.conf
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    bbr=false
}

function output()
{
    echo "WordPress安装成功！"
    echo "==============================="
    echo -e "WordPress安装路径：${red}/var/www/${domain}${plain}"
    echo -e "WordPress数据库：${red}${dbname}${plain}"
    echo -e "WordPress数据库用户名：${red}${dbuser}${plain}"
    echo -e "WordPress数据库密码：${red}${dbpass}${plain}"
    echo -e "博客访问地址：${red}http://${domain}${plain}"
    echo "==============================="

    if [ "${bbr}" == "false" ]; then
        echo  
        echo  为使BBR模块生效，系统将在30秒后重启
        echo  
        echo -e "您可以按 ctrl + c 取消重启，稍后输入 ${red}reboot${plain} 重启系统"
        sleep 30
        reboot
    fi
}

function main()
{
    checkSystem
    preInstall
    collect
    installNginx
    installPHP
    installMysql
    installWordPress
    installRedis
    installBBR

    config

    output
}

main
