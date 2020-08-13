#!/bin/bash

TMUX_CONF_URL=https://github.com/tlanyan/scripts/raw/master/files/tmux.conf
VIM_CONF_URL=https://github.com/tlanyan/scripts/raw/master/files/vim.tar.gz
BASH_CONF_URL=https://github.com/tlanyan/scripts/raw/master/files/bashrc

function checkSystem()
{
    result=$(id | awk '{print $1}')
    if [ $result != "uid=0(root)" ]; then
        echo "action must be carried out by root!"
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


function installMustHaveApps()
{
    yum -y update
    yum install -y epel-release
    yum install -y telnet curl wget dstat rsync zip unzip gzip dos2unix htop python3-pip python3-devel iftop gcc iptraf
    pip3 install --upgrade pip

    if [ $main = 7 ]; then
        yum -y remove git*
        yum -y install  https://centos7.iuscommunity.org/ius-release.rpm
        yum -y install  git2u-all
    fi
    mv -f ~/.bashrc ~/.bashrc.bak
    wget -O ~/.bashrc "${BASH_CONF_URL}"
}

function installBBR()
{
    if [ $main = 7 ]; then
        rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
        rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-4.el7.elrepo.noarch.rpm
        yum --enablerepo=elrepo-kernel install kernel-ml -y
        grub2-set-default 0
    fi
    echo "tcp_bbr" >> /etc/modules-load.d/modules.conf
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    if [ $main = 8 ]; then
        sysctl -p
    fi
}

function installTmux()
{ 
    yum install -y tmux
    wget -O ~/.tmux.conf "${TMUX_CONF_URL}"
    echo 'alias tmux="tmux -2"' >> ~/.bashrc
}

function installVim()
{
    yum install -y vim
    wget -O ~/vim.tar.gz "${VIM_CONF_URL}"
    tar -zxvf vim.tar.gz

    echo 'export EDITOR=vim' >> ~/.bashrc
}

echo -n "system version :  "
cat /etc/centos-release
checkSystem

installMustHaveApps

installBBR

installTmux

installVim

[ $main = 7 ] && reboot
