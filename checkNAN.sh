#!/bin/bash
# author: tlanyan
# link: <https://tlanyan.me/check-nan-script/>
set -e

usage() {
    echo "Usage: ./checkNAN pid logfile"
}

argc=$#
if [ $argc -lt 2 ]
then
    usage
    exit 1
fi

PID=$1
LOGFILE=$2

COMMAND=`ps -ef | grep $PID | grep -v grep | grep -v checkNAN| head -n 1 | awk '{print $8}'`
if [ "$COMMAND" = "" ]; then
    echo "unknow pid: $PID"
    exit 1
fi

if [ ! -e "$LOGFILE" ]; then
    echo "non-exists log file: $LOGFILE"
    exit 1
fi

echo "watch pid: $PID($COMMAND) for log file: $LOGFILE"

count=0
while true
do
    ret=`ps -ef | grep $PID | grep -v grep | grep -v checkNAN| head -n 1 | awk '{print $8}'`
    if [ "$ret" = "" ]; then
        echo "process quit!"
        exit 0
    fi
    ret=$(tail $LOGFILE | grep -i nan|wc -l)
    if [[ $ret -ne 0 ]]; then
        echo "nan checked!"
        tail $LOGFILE | grep nan
        echo "kill process"
        kill -9 $PID
        echo "watch exit"
        exit 0
    fi

    count=$((count+1))
    if [[ $(($count%6)) -eq 0 ]]; then
        date=$(date +'%Y-%m-%d %H-%M-%S')
        echo "$date: no nan checked..."
    fi

    sleep 20
done
