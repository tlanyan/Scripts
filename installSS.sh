#!/bin/bash
# Description: install Shadowsocks Server
# Author: tlanyan<https://tlanyan.me>

function checkSystem()
{
    result=$(id | awk '{print $1}')
    if [ $result != "uid=0(root)" ]; then
        echo "请以root身份执行该脚本！"
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

function installSS()
{
    yum update -y
    wget -O /etc/yum.repos.d/librehat-shadowsocks-epel-7.repo 'https://copr.fedorainfracloud.org/coprs/librehat/shadowsocks/repo/epel-7/librehat-shadowsocks-epel-7.repo'
    yum install -y shadowsocks-libev
     echo 'alias startSS="nohup ss-server -c /etc/shadowsocks-libev/config.json > /dev/null 2>&1 &"' >> ~/.bashrc
     echo 'alias stopSS="pkill ss-server"' >> ~/.bashrc
     systemctl disable firewalld
     systemctl stop firewalld
}

function installBBR()
{
    result=$(lsmod | grep bbr)
    if [ "$result" != "" ]; then
        echo BBR模块已安装!
        return;
    fi

    echo 安装BBR...
    rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
    rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-4.el7.elrepo.noarch.rpm
    yum --enablerepo=elrepo-kernel install kernel-ml -y
    yum remove kernel-3.* -y
    grub2-set-default 0
    echo "tcp_bbr" >> /etc/modules-load.d/modules.conf
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
}

function showTip()
{
    echo ============================================
    echo               安装成功！                  
    echo  SS配置文件：/etc/shadowsocks-libev/config.json，请按照自己需要进行修改
    echo   
    echo  你可以使用 startSS 命令启动SS服务，stopSS 命令可以停止SS服务            
    echo  
    echo  如果连接不成功，请注意查看安全组/防火墙是否已放行端口
    echo  
    echo  为使BBR模块生效，系统将在30秒后重启
    echo ============================================

    sleep 30

    reboot
}

result=$(checkSystem)
if [ "$result" != "true" ]; then
    echo "本脚本仅在CentOS 7系统上测试过!"
    exit 1
fi

echo -n "系统版本:  "
cat /etc/centos-release

installBBR

installSS

showTip
