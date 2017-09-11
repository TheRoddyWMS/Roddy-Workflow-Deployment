#!/bin/bash
# 1: Run mode, which might be run or testrun
# 2: The configuration identifier, normally ACEseq
# 3: Dataset identifiert / PID
# 4: The control bam file
# 5: The tumor bam file
# 6: The control bam sample name
# 7: The tumor bam sample name
# 8: The reference genome file path
# 9: The reference files path
# 10: The output folder
# 11: Optional: The SV file

[[ $# -lt 10 ]] && echo "Wrong number of arguments" && (head -n 10 $0 | tail -n+2) && exit 1

## Read in parameters and check files and folders
mode=${1}
configurationIdentifier=${2}
pid=${3}

inputBamCtrlLcl=`readlink -f ${4}`
inputBamTumorLcl=`readlink -f ${5}`
inputBamCtrlSampleName=${6}
inputBamTumorSampleName=${7}
referenceGenomePath=`dirname ${8}`
referenceFilePath=`dirname ${9}`
workspaceLcl=`readlink -f ${10}`

function checkFile() {
	local _file=${1}
	[[ ! -r ${_file} || ! -f ${_file} ]] && echo "File ${_file} is not readable or not a file." && exit 1
}

function checkDir() {
	local _dir=${1}
	local _rw=${2-r}
	
	if [[ $_rw == "r" ]]; then
		[[ ! -r ${_dir} || ! -d ${_dir} ]] && echo "Dir ${_dir} is not readable or not a directory" && exit 2
	elif [[ $_rw == "rw" ]]; then
		[[ ! -r ${_dir} || ! -w ${_dir} || ! -d ${_dir} ]] && echo "Dir ${_dir} is not readable or not writable or not a directory" && exit 2
	fi
}

[[ $mode -ne "run" && $mode -ne "testrun" ]] && echo "Mode must be run or testrun" && exit 2
checkFile $inputBamCtrlLcl 
checkFile $inputBamTumorLcl 
checkDir $referenceGenomePath 
checkDir $referenceFilePath 
checkDir $workspaceLcl rw

if [[ $# -eq 11 ]]; then
	# Either use the file
	local svFile=`readlink -f ${11}`
	checkFile $svFile
	svBlock="svFile:${svFile}"
else 
	# or explicitely disable it.
	svBlock="runWithSv:false,SV:no"
fi

# Define in-Docker files and folders

workspace=/home/roddy/workspace
configurationFolder=/home/roddy/config
inputBamCtrl=${inputBamCtrlLcl}
inputBamTumor=${inputBamTumorLcl}

# Kortine, you need to set these!
referenceGenomeFolder=... 
referenceFilesFolder=

roddyBinary="bash /home/roddy/binaries/Roddy/roddy.sh"
roddyConfig="--useconfig=/home/roddy/config/config.ini"
bamFiles="bamfile_list:$inputBamCtrl;$inputBamTumor"
sampleList="sample_list:${inputBamCtrlSampleName};${inputBamTumorSampleName}"
tumorSample="tumorSample:${inputBamTumorSampleName}

# Kortine, do you need to set this? ,REFERENCE_GENOME:${referenceGenome}
call="${roddyBinary} ${mode} ${configurationIdentifier}@copyNumberEstimation ${pid} ${roddyConfig} --cvalues=\"${bamFiles},${svBlock},${sampleList},${tumorSample}\""

# Change group and user id to match your system user and group
sed "s/:1000:1000:/:`id -u`:`id -g`:/" passwdfile > passwdtemp
sed "s/:1000:/:`id -g`:/" groupfile > grouptemp

 
echo docker run --user `id -u`:`id -g` -v `readlink -f passwdtemp`:/etc/passwd \
		   -v `readlink -f grouptemp`:/etc/group \
		   -v ${inputBamCtrlLcl}:${inputBamCtrl} -v ${inputBamCtrlLcl}.bai:${inputBamCtrl}.bai \
		   -v ${inputBamTumorLcl}:${inputBamTumor} -v ${inputBamTumorLcl}.bai:${inputBamTumor}.bai \
		   -v ${workspaceLcl}:${workspace} \
		   -v ${referenceGenomePath}:${referenceGenomePath} \
		   -v ${referenceFilePath}:${referenceFilePath} \
		   -v `readlink -f config`:${configurationFolder} \
		   -t -i aceseqimage \
			/bin/bash -c "$call; ec=$?"
