#!/bin/bash
#echo `head -n 1 /etc/hosts | cut -f 1` master > /tmp/hostsTmp
#tail -n +2 /etc/hosts >> /tmp/hostsTmp
#cp /tmp/hostsTmp /etc/hosts && echo master > /etc/hostname
#hostName=`hostname`
#export HOST=$hostName

sudo qconf -ae `hostname`
sudo qconf -as `hostname`
sudo qconf -sq main.q | sed "s/hostlist.*/hostlist\t\t`hostname` @allhosts/g" | sed "s/slots.*/slots\t\t1,[`hostname`]/g" > /home/roddy/main.q
sudo qconf -Mq /home/roddy/main.q

/etc/init.d/gridengine-exec stop
/etc/init.d/gridengine-master restart
/etc/init.d/gridengine-exec start
