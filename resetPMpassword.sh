#!/bin/bash
# reset password of parallels desktop VMs
# link: <https://tlanyan.me/script-to-reset-password-of-parallels-desktop-vms>
#author tlanyan<tlanyan@hotmail.com>

prlctl list -a
machines=`prlctl list -a|sed '1d'`
count=`echo "$machines"|wc -l`
((count--))
read -p "please select vm index[0-$count]:" index
if [ $index -gt $count ]; then
    echo "invlid choice!"
    exit
fi

((index++))
line=`echo "$machines" | sed -n ${index}p`
echo your choice: $line

id=`echo "$line" | tr '{}' '  ' | awk '{print $1}'`

read -p "please input username:" username
read -p "release input password:" password
prlctl set $id --userpasswd $username:$password
