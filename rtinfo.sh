#!/bin/bash
#
# Quick and dirty script to grab info needed for RT 
# To be run on a machine to summarize the info in a format
# ready to be put in RT. 
# 
# John R. Hover <jhover@bnl.gov>
#
#
echo hostname `hostname`

nn=`hostname | awk -F "." '{print $1}'`
echo nodename $nn

nm=`/sbin/ifconfig | grep Bcast | awk '{print $4}'| awk -F ":" '{print $2}'`
echo netmask $nm

gw=`/sbin/route -n | grep "^0.0.0.0" | awk '{print $2}'`
echo gateway $gw

echo os `cat /etc/redhat-release`

echo kernel `uname -r`

echo no_cpu `cat /proc/cpuinfo  | grep processor | wc -l`

echo cpu_speed `cat /proc/cpuinfo | grep MHz | uniq  | awk '{print $4}'`

mk=`cat /proc/meminfo  | grep MemTotal | awk '{print $2}'`
memmeg=$(( $mk / 1000))
echo memory $memmeg

#
# Print out info for main ethernet interface
#
echo  `/sbin/ifconfig | grep eth | awk '{print $1}'`  `/sbin/ifconfig | grep eth -C 1 | grep inet | awk '{print $2}' | awk -F ":" '{print $2}'` `/sbin/ifconfig | grep eth | awk '{print $5}' | tr -d ":"`



#
# Determine all open tcp ports
#
`netstat -tln | grep tcp > /tmp/nsfile.tmp`
getport () {

        while read line ; do
                echo $line | awk '{print $4}' | egrep -o ":[[:digit:]]+$" | tr -d ":"  >> /tmp/tcpports.tmp
        echo " " >> /tmp/tcpports.tmp
        done
}
getport < /tmp/nsfile.tmp
tcpports=`cat /tmp/tcpports.tmp | tr -d "\n"`
echo tcpports $tcpports
rm /tmp/nsfile.tmp /tmp/tcpports.tmp





