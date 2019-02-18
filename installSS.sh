#!/bin/bash
# Description: install Shadowsocks Server
# Author: tlanyan<https://tlanyan.me>

function checkSystem()
{
    result=$(id | awk '{print $1}')
    if [ $result != "uid=0(root)" ]; then
        sudo -i
    fi
    result=$(id | awk '{print $1}')
    if [ $result != "uid=0(root)" ]; then
        echo "action must be carried out by root!"
        exit 1
    fi

    if [ ! -f /etc/centos-release ];then
        echo false
        return
    fi
    echo -n "system version :  "
    cat /etc/centos-release
    
    result=`cat /etc/centos-release|grep "CentOS Linux release 7"`
    if [ "$result" = "" ]; then
        echo false
    fi
    echo true
}

function installSS()
{
    wget -O /etc/yum.repos.d/librehat-shadowsocks-epel-7.repo 'https://copr.fedorainfracloud.org/coprs/librehat/shadowsocks/repo/epel-7/librehat-shadowsocks-epel-7.repo'
    yum install -y shadowsocks-libev
     echo 'alias startSS="nohup ss-server -c /etc/shadowsocks-libev/config.json > /dev/null 2>&1 &"' >> ~/.bashrc
     echo 'alias stopSS="pkill ss-server"' >> ~/.bashrc
}

result=$(checkSystem)
if [ $result = "false" ]; then
    echo "scripts only tested on centos 7!"
    exit 1
fi

installSS
