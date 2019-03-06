#!/bin/bash
# Description: install Node.js
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

function installNodeJS()
{
    curl -sL https://rpm.nodesource.com/setup_10.x | bash -
    npm install -g cnpm --registry=https://registry.npm.taobao.org
    cnpm install -g jshint csshint

    echo 'alias npm=cnpm' >> ~/.bashrc
}

result=$(checkSystem)
if [ "$result" != "true" ]; then
    echo "scripts only tested on centos 7!"
    exit 1
fi

echo -n "system version :  "
cat /etc/centos-release

installNodeJS
