#!/bin/bash

# SGE looks up the UID and GID of the user running SGE in /etc/passwd and /etc/group
# update the IDs to match the user running the docker/singularity container
if [ $(id -g) -ne 0 ]; then
	NEW_GROUP=$(sed -e "s|^roddy:.*|roddy:x:$(id -g):|" /etc/group)
	rm -f /etc/group 2> /dev/null
	echo "$NEW_GROUP" > /etc/group
fi
if [ $(id -u) -ne 0 ]; then
	NEW_PASSWD=$(sed -e "s|^roddy:.*|roddy:x:$(id -u):$(id -g)::/home/roddy:/bin/sh|" /etc/passwd)
	rm -f /etc/passwd 2> /dev/null
	echo "$NEW_PASSWD" > /etc/passwd
fi

# update the host name to match the containers name
export HOSTNAME=$(hostname)
if ! grep -q $HOSTNAME /etc/hostname; then
	rm -f /etc/hostname
	echo "$HOSTNAME" > /etc/hostname
fi
if ! grep -q $HOSTNAME /etc/hosts; then
	rm -f /etc/hosts
	echo "127.0.0.1 $HOSTNAME ${HOSTNAME%%.*}" > /etc/hosts
fi
echo "$HOSTNAME" > /var/lib/gridengine/default/common/act_qmaster

# make a directory for temp files
TEMP_FILES=$(mktemp -d)

# move spool directory of qmaster to a writable location (required for singularity)
cp -r /var/spool/gridengine.template "$TEMP_FILES/gridengine"
ln -s "$TEMP_FILES/gridengine" /var/spool/gridengine

# launch qmaster
/etc/init.d/gridengine-master start
sleep 10

# add container to SGE queue
qconf -ah $HOSTNAME
qconf -as $HOSTNAME
qconf -mattr queue hostlist "$HOSTNAME @allhosts" main.q
qconf -mattr queue slots "1,[$HOSTNAME=8]" main.q

# launch execution daemon
/etc/init.d/gridengine-exec start

# move .roddy directory to a writable location (required for singularity)
cp -r /home/roddy/.roddy.template "$TEMP_FILES/.roddy"
ln -s "$TEMP_FILES/.roddy" /home/roddy/.roddy

# run roddy command passed to docker container as argument
export HOME=/home/roddy
"$@"
echo "Wait for Roddy to finish"
while [[ 2 -lt $(qstat | wc -l ) ]]; do
	echo $(expr $(qstat | wc -l) - 2 )" jobs are still in the list"
	sleep 120
done
echo "done"

# cleanup
/etc/init.d/gridengine-exec stop
/etc/init.d/gridengine-master stop
rm -rf "$TEMP_FILES"

