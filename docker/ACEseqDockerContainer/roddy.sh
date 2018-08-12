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
configurationFolder=`readlink -f "${3}"`
pid=${4}

inputBamCtrl=`readlink -f "${5}"`
inputBamTumor=`readlink -f "${6}"`
inputBamCtrlSampleName=${7}
inputBamTumorSampleName=${8}
referenceGenomeFile=`readlink -f "${9}"`
referenceFilesPath=`readlink -f "${10}"`
workspace=`readlink -f "${11}"`

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
checkFile ${referenceGenomeFile}
checkFile ${referenceGenomeFile}.fai
checkDir $referenceFilesPath 
checkDir $workspace rw

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
roddyBinary="bash /home/roddy/binaries/Roddy/roddy.sh"
roddyConfig="--useconfig=${configurationFolder}/ini/alllocal.ini"
bamFiles="bamfile_list:$inputBamCtrl;$inputBamTumor"
sampleList="sample_list:${inputBamCtrlSampleName};${inputBamTumorSampleName}"
sampleListParameters="possibleTumorSampleNamePrefixes:(${inputBamTumorSampleName}),possibleControlSampleNamePrefixes:(${inputBamCtrlSampleName})"
tumorSample="tumorSample:${inputBamTumorSampleName}"
baseDirectoryReference="baseDirectoryReference:${referenceFilesPath}"
referenceGenome="REFERENCE_GENOME:${referenceGenomeFile}"
outputBaseDirectory="outputBaseDirectory:${workspace}"
outputFileGroup="outputFileGroup:roddy"

call="${roddyBinary} ${mode} ACEseq@copyNumberEstimation ${pid} ${roddyConfig} --cvalues='${bamFiles},${svBlock},${sampleList},${sampleListParameters},${tumorSample},${referenceGenome},${baseDirectoryReference},${outputBaseDirectory},${outputFileGroup}'"

mkdir -p "${workspace}/${pid}"

if [ "$container" = "docker" ]; then
	docker run \
		-v "${inputBamCtrl}:${inputBamCtrl}:ro" -v "${inputBamCtrl}.bai:${inputBamCtrl}.bai:ro" \
		-v "${inputBamTumor}:${inputBamTumor}:ro" -v "${inputBamTumor}.bai:${inputBamTumor}.bai:ro" \
		-v "${workspace}:${workspace}" \
		-v "${referenceGenomeFile}:${referenceGenomeFile}:ro" -v "${referenceGenomeFile}.fai:${referenceGenomeFile}.fai:ro" \
		-v "${referenceFilesPath}:${referenceFilesPath}:ro" \
		-v "${configurationFolder}:${configurationFolder}:ro" \
		$([ -n "${svFile}" ] && echo -v "${svFile}:${svFile}:ro") \
		--rm \
		--shm-size=1G \
		--user $(id -u):$(id -g) \
		-t -i aceseqimage \
		/bin/bash -c "$call"
else
	singularity exec \
		-B /tmp:/tmp \
		-B "${inputBamCtrl}:${inputBamCtrl}:ro" -B "${inputBamCtrl}.bai:${inputBamCtrl}.bai:ro" \
		-B "${inputBamTumor}:${inputBamTumor}:ro" -B "${inputBamTumor}.bai:${inputBamTumor}.bai:ro" \
		-B "${workspace}:${workspace}" \
		-B "${referenceGenomeFile}:${referenceGenomeFile}:ro" -B "${referenceGenomeFile}.fai:${referenceGenomeFile}.fai:ro" \
		-B "${referenceFilesPath}:${referenceFilesPath}:ro" \
		-B "${configurationFolder}:${configurationFolder}:ro" \
		$([ -n "${svFile}" ] && echo -B "${svFile}:${svFile}:ro") \
		--containall --net \
		$(dirname "$0")/singularity.img \
		/ENTRYPOINT.sh /bin/bash -c "$call"
fi

