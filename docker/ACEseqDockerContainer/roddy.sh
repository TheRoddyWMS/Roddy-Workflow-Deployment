#!/bin/bash
# 1: Run mode, which might be "run" or "testrun"
# 2: Container type, "docker" or "singularity"
# 3: Configuration directory
# 4: Dataset identifier / PID
# 5: Control bam file
# 6: Tumor bam file
# 7: Control bam sample name
# 8: Tumor bam sample name
# 9: Reference genome file
# 10: Reference files path
# 11: Output folder
# 12: Optional: The SV file

if [[ $# -lt 11 ]]; then
	echo "Wrong number of arguments"
	head -n 13 "$0" | tail -n+2
	exit 1
fi

## Read in parameters and check files and folders
mode=${1}
container=${2}
configurationFolderLcl=`readlink -f "${3}"`
pid=${4}

inputBamCtrlLcl=`readlink -f "${5}"`
inputBamTumorLcl=`readlink -f "${6}"`
inputBamCtrlSampleName=${7}
inputBamTumorSampleName=${8}
referenceGenomeFile=`readlink -f "${9}"`
referenceFilesPath=`readlink -f "${10}"`
workspaceLcl=`readlink -f "${11}"`

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
[ "$container" != "docker" -a "$container" != "singularity" ] && echo "Container must be docker or singularity" && exit 2
checkFile $inputBamCtrlLcl 
checkFile $inputBamTumorLcl 
checkFile ${referenceGenomeFile}
checkDir $referenceFilesPath 
checkDir $workspaceLcl rw

if [[ $# -eq 13 ]]; then
	# Either use the file
	svFile=`readlink -f ${12}`
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

roddyBinary="bash /home/roddy/binaries/Roddy/roddy.sh"
roddyConfig="--useconfig=/home/roddy/config/ini/alllocal.ini"
bamFiles="bamfile_list:$inputBamCtrl;$inputBamTumor"
sampleList="sample_list:${inputBamCtrlSampleName};${inputBamTumorSampleName}"
sampleListParameters="possibleTumorSampleNamePrefixes:(${inputBamTumorSampleName}),possibleControlSampleNamePrefixes:(${inputBamCtrlSampleName})"
tumorSample="tumorSample:${inputBamTumorSampleName}"
baseDirectoryReference="baseDirectoryReference:${referenceFilesPath}"
referenceGenome="REFERENCE_GENOME:${referenceGenomeFile}"
referenceGenomePath=`dirname ${referenceGenomeFile}`
outputBaseDirectory="outputBaseDirectory:${workspace}"
outputFileGroup="outputFileGroup:roddy"

call="${roddyBinary} ${mode} ACEseq@copyNumberEstimation ${pid} ${roddyConfig} --cvalues=\"${bamFiles},${svBlock},${sampleList},${sampleListParameters},${tumorSample},${referenceGenome},${baseDirectoryReference},${outputBaseDirectory},${outputFileGroup}\""

absoluteCall="[[ ! -d ${workspace}/${pid} ]] && mkdir ${workspace}/${pid}; $call; echo \"Wait for Roddy to finish\"; "'while [[ 2 -lt $(qstat | wc -l ) ]]; do echo $(expr $(qstat | wc -l) - 2 )\" jobs are still in the list\"; sleep 120; done;'" echo \"done\"; ec=$?"

if [ "$container" = "docker" ]; then
	docker run \
		-v "${inputBamCtrlLcl}:${inputBamCtrl}:ro" -v "${inputBamCtrlLcl}.bai:${inputBamCtrl}.bai:ro" \
		-v "${inputBamTumorLcl}:${inputBamTumor}:ro" -v "${inputBamTumorLcl}.bai:${inputBamTumor}.bai:ro" \
		-v "${workspaceLcl}:${workspace}" \
		-v "${referenceGenomePath}:${referenceGenomePath}:ro" \
		-v "${referenceFilesPath}:${referenceFilesPath}:ro" \
		-v "${configurationFolderLcl}:${configurationFolder}:ro" \
		$([ -n "${svFile}" ] && echo -v "${svFile}:${svFile}:ro") \
		--rm \
		--shm-size=1G \
		--user $(id -u):$(id -g) \
		-t -i aceseqimage \
		/bin/bash -c "$absoluteCall"
else
	singularity exec \
		-B /tmp:/tmp \
		-B "${inputBamCtrlLcl}:${inputBamCtrl}:ro" -B "${inputBamCtrlLcl}.bai:${inputBamCtrl}.bai:ro" \
		-B "${inputBamTumorLcl}:${inputBamTumor}:ro" -B "${inputBamTumorLcl}.bai:${inputBamTumor}.bai:ro" \
		-B "${workspaceLcl}:${workspace}" \
		-B "${referenceGenomePath}:${referenceGenomePath}:ro" \
		-B "${referenceFilesPath}:${referenceFilesPath}:ro" \
		-B "${configurationFolderLcl}:${configurationFolder}:ro" \
		$([ -n "${svFile}" ] && echo -B "${svFile}:${svFile}:ro") \
		--containall --net \
		$(dirname "$0")/singularity.img \
		/ENTRYPOINT.sh /bin/bash -c "$absoluteCall"
fi

