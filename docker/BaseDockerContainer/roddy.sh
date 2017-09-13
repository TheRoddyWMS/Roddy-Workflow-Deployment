# 1:PID
# 2:CON
# 3:TUM
# 4:OUT
# 5:TEST?
set -xuv
pid=$1
inputBamCtrl=/workspace/input/`basename $2`
inputBamTumor=/workspace/input/`basename $3`
test=false
[[ ${5-false} == debug ]] && test=true

call="/home/roddy/binaries/Roddy/roddy.sh testrun project@indelCalling ${pid} --useconfig=/home/roddy/configuration/config.ini --cvalues=\"bamfile_list:$inputBamCtrl;$inputBamTumor\""
[[ $test == true ]] && call=/bin/bash


docker run -v `readlink -f ${2}`:${inputBamCtrl} -v `readlink -f ${2}.bai`:${inputBamCtrl}.bai \
	   -v `readlink -f ${3}`:${inputBamTumor} -v `readlink -f ${3}`.bai:${inputBamTumor}.bai \
	   -v `readlink -f $4`:/workspace/output \
	   -t -i roddyplatypus \
	   --user 0 --env=RUN_AS_UID=`id -u` --env=RUN_AS_GID=`id -g` \
	   /bin/bash -c "mkdir -p /workspace/output/$pid/alignment; ln -sf /workspace/input/*.bam* /workspace/output/$pid/alignment; $call; chmod -R a+w /workspace/output"
