#!/bin/bash
# Description: set iptables rules
# Author: tlanyan<https://tlanyan.me>
iptables -P INPUT ACCEPT
iptables -F
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -p tcp -m state --state ESTABLISHED -j ACCEPT
# ssh
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
# dns
iptables -A INPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --sport 53 -j ACCEPT
iptables -P INPUT DROP
