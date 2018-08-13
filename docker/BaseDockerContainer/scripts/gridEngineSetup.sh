#!/bin/bash

function setupHost() {
	echo "SetupHost"
	
	#forceApplySGEHost
	grep 127.0.0.1 /etc/hosts | grep master
	if [[ $? == 1 ]]; then
		echo '127.0.0.1 master' | cat - /etc/hosts > /tmp/tmp_host && cp /tmp/tmp_host /etc/hosts
	fi
	echo master > /etc/hostname
	hostName=`hostname`
	export HOST=$hostName
	export HOSTNAME=$hostName
	echo $HOSTNAME
}

function forceApplySGEHost() {
	echo "ForceApply"
	local _dir=/var/lib/gridengine/default/common
	local _file=/var/lib/gridengine/default/common/act_qmaster
	[[ ! -d $_dir ]] && mkdir -p $_dir
	sudo bash -c "hostname > ${_file}"
	cat ${_file}
}

# Initial start of grid engine
function jumpStartGridEngine() {
	echo "JumpStart"
	
	forceApplySGEHost
	cat /var/lib/gridengine/default/common/act_qmaster
	
	sudo /etc/init.d/gridengine-master restart;
	sudo /etc/init.d/gridengine-exec start;
}

function prepareMainQScript() { 
	echo "PrepareMainQScript"
	
	forceApplySGEHost
	echo "host=`hostname`" > /home/roddy/prepareMainQ.sh; 
	echo "touch /home/roddy/main.q && chmod a+rw /home/roddy/main.q" >> /home/roddy/prepareMainQ.sh
	echo 'qconf -sq main.q | sed "s/hostlist*/hostlist\t\t${host} @allhosts/g" | sed "s/slots*/slots\t\t1,[${host}=8]/g" > /home/roddy/main.q' >> /home/roddy/prepareMainQ.sh; 
	
	ll /home/roddy/
	cat /home/roddy/main.q
}


# Reconfigure and restart grid engine (jumpstart necessary first!)
function restartGridEngine() {
	echo "Restart"
	
	#forceApplySGEHost
	#(ps -ef  | grep usr  | grep  sge | awk '{print $2}' | xargs sudo kill 2> /dev/null)
	#set -xv
	#local host=`hostname`
	#sudo qconf -ah $host
	#sudo qconf -as $host

	#prepareMainQScript

	#sudo bash -c "/bin/bash /home/roddy/prepareMainQ.sh"
	
	#echo "-----"
	#cat /home/roddy/main.q
	#echo "-----"
	#sleep 2
	
	#sudo qconf -Mq /home/roddy/main.q
	
	sudo /etc/init.d/gridengine-exec stop;
	sudo /etc/init.d/gridengine-master restart;
	sudo /etc/init.d/gridengine-exec start;
	#set +xv
}

function installGridEngine() {
	echo "Install SGE"
	apt-get update && apt-get -q -y --force-yes install gridengine-client gridengine-common gridengine-exec gridengine-master;
	restartGridEngine
    qconf -am roddy
    qconf -au roddy users
    qconf -as $HOST
	# make SGE-related files writable for everyone to enable running SGE as any user
	chmod -R a+rw /var/lib/gridengine /var/run/gridengine /var/spool
	chmod a+rw /etc /etc/passwd /etc/group
	# define roddy as the user to run SGE (required by Singularity)
	sed -i -e 's/admin_user.*/admin_user roddy/' /etc/gridengine/bootstrap /var/lib/gridengine/default/common/bootstrap
}

# some parameters of gridengine can only be modified using an interactive editor
# this function creates a temporary non-interactive script that mimicks an interactive editor
# Usage: changeGridEngineConfig PARAMETER_TO_CHANGE NEW_VALUE QCONF_ARGUMENTS
function changeGridEngineConfig() {
PARAMETER="$1"
VALUE="$2"
QCONF_ARGS="$3"
NEW_QCONF=$(mktemp)
cat > "$NEW_QCONF" <<EOF
#!/bin/bash
sleep 1
sed -i -e 's|$PARAMETER.*|$PARAMETER $VALUE|' "\$1"
EOF
chmod a+x "$NEW_QCONF"
(export EDITOR="$NEW_QCONF"; qconf $QCONF_ARGS)
rm -f "$NEW_QCONF"
}

function setupGridEngine() {
changeGridEngineConfig hostname "$hostName" -ae
changeGridEngineConfig group_name @allhosts -ahgrp
changeGridEngineConfig hostlist "$hostName" "-mhgrp @allhosts"
qconf -aattr hostgroup hostlist "$hostName" @allhosts
changeGridEngineConfig qname main.q "-aq main.q"
qconf -aattr queue hostlist @allhosts main.q
qconf -aattr queue slots "[$hostName=`nproc`]" main.q
qconf -mattr queue load_thresholds "np_load_avg=`nproc`" main.q
qconf -rattr exechost complex_values s_data=`free -b |grep Mem | cut -d" " -f5` "$hostName"
TMPPROFILE=/tmp/serial.profile
echo "pe_name           serial
	slots             9999
	user_lists        NONE
	xuser_lists       NONE
	start_proc_args   /bin/true
	stop_proc_args    /bin/true
	allocation_rule   \$pe_slots
	control_slaves    FALSE
	job_is_first_task TRUE
	urgency_slots     min
	accounting_summary FALSE" > $TMPPROFILE
qconf -Ap $TMPPROFILE
qconf -aattr queue pe_list serial main.q
rm $TMPPROFILE
/etc/init.d/gridengine-exec stop
sleep 4
/etc/init.d/gridengine-master stop
sleep 4
pkill -9 sge_execd
pkill -9 sge_qmaster
sleep 4
rm -f /var/spool/gridengine/qmaster/lock
}
