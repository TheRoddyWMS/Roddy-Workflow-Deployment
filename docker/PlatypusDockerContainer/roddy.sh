#!/bin/bash
# 1: Run mode, which might be "run" or "testrun"
# 2: Container type, "docker" or "singularity"
# 3: Dataset identifier / PID
# 4: Control bam file
# 5: Tumor bam file
# 6: Control bam sample name
# 7: Tumor bam sample name
# 8: Reference genome file
# 9: Reference files path
# 10: Output folder

if [[ $# -ne 10 ]]; then
	echo "Wrong number of arguments"
	head -n 11 "$0" | tail -n+2
	exit 1
fi

## Read in parameters and check files and folders
mode=${1}
container=${2}
pid=${3}

inputBamCtrl=`readlink -f "${4}"`
inputBamTumor=`readlink -f "${5}"`
inputBamCtrlSampleName=${6}
inputBamTumorSampleName=${7}
referenceGenomeFile=`readlink -f "${8}"`
referenceFilesPath=`readlink -f "${9}"`
workspace=`readlink -f "${10}"`

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
checkFile $inputBamCtrl 
checkFile $inputBamTumor 
checkDir $referenceFilesPath 
checkDir $workspace rw

# Define in-Docker files and folders

roddyBinary="bash /home/roddy/binaries/Roddy/roddy.sh"
roddyConfig="--useconfig=/home/roddy/config/ini/alllocal.ini"
bamFiles="bamfile_list:$inputBamCtrl;$inputBamTumor"
sampleList="sample_list:${inputBamCtrlSampleName};${inputBamTumorSampleName}"
sampleListParameters="possibleTumorSampleNamePrefixes:(${inputBamTumorSampleName}),possibleControlSampleNamePrefixes:(${inputBamCtrlSampleName})"
tumorSample="tumorSample:${inputBamTumorSampleName}"
hg19DatabasesDirectory="hg19DatabasesDirectory:${referenceFilesPath}"
referenceGenome="REFERENCE_GENOME:${referenceGenomeFile}"
outputBaseDirectory="outputBaseDirectory:${workspace}"
outputFileGroup="outputFileGroup:roddy"

call="${roddyBinary} ${mode} Platypus@IndelCallingWorkflow ${pid} ${roddyConfig} --cvalues='${bamFiles},${sampleList},${sampleListParameters},${tumorSample},${referenceGenome},${hg19DatabasesDirectory},${outputBaseDirectory},${outputFileGroup}'"

mkdir -p "${workspace}/${pid}"

if [ "$container" = "docker" ]; then
	docker run \
		-v "${inputBamCtrl}:${inputBamCtrl}:ro" -v "${inputBamCtrl}.bai:${inputBamCtrl}.bai:ro" \
		-v "${inputBamTumor}:${inputBamTumor}:ro" -v "${inputBamTumor}.bai:${inputBamTumor}.bai:ro" \
		-v "${workspace}:${workspace}" \
		-v "${referenceGenomeFile}:${referenceGenomeFile}:ro" -v "${referenceGenomeFile}.fai:${referenceGenomeFile}.fai:ro" \
		-v "${referenceFilesPath}:${referenceFilesPath}:ro" \
		--rm \
		--shm-size=1G \
		--user $(id -u):$(id -g) \
		platypusimage \
		/bin/bash -c "$call"
else
	singularity exec \
		-B /tmp:/tmp \
		-B "${inputBamCtrl}:${inputBamCtrl}:ro" -B "${inputBamCtrl}.bai:${inputBamCtrl}.bai:ro" \
		-B "${inputBamTumor}:${inputBamTumor}:ro" -B "${inputBamTumor}.bai:${inputBamTumor}.bai:ro" \
		-B "${workspace}:${workspace}" \
		-B "${referenceGenomeFile}:${referenceGenomeFile}:ro" -B "${referenceGenomeFile}.fai:${referenceGenomeFile}.fai:ro" \
		-B "${referenceFilesPath}:${referenceFilesPath}:ro" \
		--containall --net \
		$(dirname "$0")/singularity.img \
		/ENTRYPOINT.sh /bin/bash -c "$call"
fi

