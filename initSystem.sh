#!/bin/bash

TMUX_CONF_URL=https://github.com/tlanyan/scripts/blob/master/files/tmux.conf
VIM_CONF_URL=https://github.com/tlanyan/scripts/blob/master/files/vim.tar.gz
BASH_CONF_URL=https://github.com/tlanyan/scripts/blob/master/files/bashrc

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

function updateSystem()
{ 
    yum -y update
    yum install -y epel-release
}

function installMustHaveApps()
{
    # must have app list: https://tlanyan.me/must-have-apps/
    yum install -y telnet curl wget dstat rsync zip unzip git dos2unix htop python36-pip python36-devel iftop
    yum remove -y python34
    pip3 install --upgrade pip
    pip3 install thefuck
    eval $(thefuck --alias)
    echo 'eval $(thefuck --alias)' >> ~/.bashrc

    mv -f ~/.bashrc ~/.bashrc.bak
    wget -O ~/.bashrc "${BASH_CONF_URL}"
}

function installBBR()
{
    rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
    rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm
    yum --enablerepo=elrepo-kernel install kernel-ml -y
    yum remove kernel-3.* -y
    grub2-set-default 0
    echo "tcp_bbr" >> /etc/modules-load.d/modules.conf
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
}

function installZsh()
{
    yum install -y zsh
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
    chsh -s /bin/zsh

    echo 'ZSH_THEME="agnoster"' >> ~/.zshrc
    echo 'source ~/.bashrc' >> ~/.zshrc
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

result=$(checkSystem)
if [ $result = "false" ]; then
    echo "scripts only tested on centos 7!"
    exit 1
fi

updateSystem

installMustHaveApps

installBBR

installZsh

installTmux

installVim

reboot
