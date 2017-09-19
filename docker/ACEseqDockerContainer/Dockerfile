FROM roddybaseimage_xenial1604
#FROM roddybaseimage:latest
MAINTAINER Michael Heinold @ DKFZ


# Settings for ACEseq Worfklow by Kortine Kleinheinz, DKFZ

USER roddy

# Install Bioconda

RUN sudo apt-get update; sudo apt-get install -y bzip2 git

RUN cd /home/roddy; \
	echo "Download Anaconda https://repo.continuum.io/archive/Anaconda2-4.4.0-Linux-x86_64.sh"; \
	wget -q https://repo.continuum.io/archive/Anaconda2-4.4.0-Linux-x86_64.sh && \
	echo "Install Anaconda" && \
	sudo bash Anaconda2-4.4.0-Linux-x86_64.sh -b && \
	rm -rf Anaconda2-4.4.0-Linux-x86_64.sh && \
	echo Done && \
	export PATH=/home/roddy/anaconda2/bin/:$PATH

ENV PATH=/home/roddy/anaconda2/bin/:$PATH

RUN env; \
	conda config --add channels r; \
	conda config --add channels defaults; \
	conda config --add channels conda-forge; \
	conda config --add channels bioconda;

# Clone or download Roddy
# Clone or download ACEseq && COWorkflows Plugin, put them to the Roddy directory
# Create or add configuration files.

ENV BINARIES_FOLDER /home/roddy/binaries

ENV RODDY_PLUGINS_R2_4 $BINARIES_FOLDER/Roddy/plugins_R2.4

ENV RODDY_BASE_PLUGINS $BINARIES_FOLDER/Roddy/dist/plugins

ENV ACESEQ_FOLDER $RODDY_PLUGINS_R2_4/ACEseqWorkflow_1.2.10

ENV COWORKFLOWS_FOLDER $RODDY_PLUGINS_R2_4/COWorkflowsBasePlugins

# Prepare the Roddy setup, also prepare Default and Base plugin
RUN mkdir -p $BINARIES_FOLDER && cd $BINARIES_FOLDER && \
	rm -rf $BINARIES_FOLDER/Roddy &&  \
	git clone https://github.com/eilslabs/Roddy.git &&  \
	cd Roddy &&  git checkout 2.4.10b &&  mkdir -p plugins_R2.4 &&  \
	ls -l && \
	ls -l .git/ && \
#	git submodule add -f  https://github.com/eilslabs/Roddy-Base-Plugin.git dist/plugins/PluginBase && \
#	git submodule add -f  https://github.com/eilslabs/Roddy-Default-Plugin.git dist/plugins/DefaultPlugin && \
	git submodule foreach git fetch --tags && \
	git submodule update --init --recursive && \
	cd $RODDY_BASE_PLUGINS &&  \
	ls -l && \
	(cd DefaultPlugin && git checkout 1.2.0) && \
	(cd PluginBase && git checkout 1.2.0) && \
	cp -r DefaultPlugin DefaultPlugin_1.2.0 &&  \
	cp -r PluginBase PluginBase_1.2.0

# Install ACEseq, so we can install the Conda environment, the only reason, why it is before the other installation commands is, that the process 
# takes quite long and it is nicer for intermediate builds.
RUN cd $RODDY_PLUGINS_R2_4 && \
	git  clone https://github.com/eilslabs/ACEseqWorkflow ACEseqWorkflow_1.2.10 && \
	cd ACEseqWorkflow_1.2.10  &&  \
	git checkout 1.2.10
	
RUN	conda env create -n ACEseqWorkflow -f $ACESEQ_FOLDER/resources/analysisTools/copyNumberEstimationWorkflow/environments/conda.yml;

# Install Groovy 2.4.7 from Maven. OpenJDK is already installed in the base image so just link it..
RUN mkdir -p ~/.roddy/runtimeDevel && cd ~/.roddy/runtimeDevel && \
	groovyArchive=$(curl -s https://dl.bintray.com/groovy/maven/ 2>&1  | grep groovy | grep 2.4.7 | grep -v ".asc" | sed 's/href=":/\n/g' | sed 's/>/\n/g' | sed 's/</\n/g' | grep groovy | grep "binary"| grep -v "rel="  | grep -v "md5" | sort -V) && \
	groovyZipLink="https://dl.bintray.com/groovy/maven/"$(echo $groovyArchive | tail -n 1) && \
	wget $groovyZipLink && \
	unzip $groovyArchive && \
	rm $groovyArchive && \
	ln -sf /usr/lib/jvm/java-8-openjdk-amd64 ~/.roddy/runtimeDevel/jdk && ln -sf ~/.roddy/runtimeDevel/jdk ~/.roddy/runtimeDevel/jdk1.8.0_131

# Currently not needed. Both are packed in R2.4.10
#RUN cd $BINARIES_FOLDER && \
#	git clone https://github.com/eilslabs/BatchEuphoria && \
#	cd $BINARIES_FOLDER/BatchEuphoria && \
#	git checkout SGE-Direct-Beta-Release-1 && \
#	./gradlew build	&& cp build/libs/BatchEuphoria.jar $BINARIES_FOLDER/Roddy/dist/bin/current/lib 
	
#RUN cd $BINARIES_FOLDER && \
#	git clone https://github.com/eilslabs/RoddyToolLib.git RoddyToolLib && \
#	cd $BINARIES_FOLDER/RoddyToolLib && \
#	git checkout BEwSGEaDirectSup_R2.4.8b && \
#	./gradlew build && ls -lahtr build/libs && cp $(ls -ahtr build/libs/R* | tail -n 1) $BINARIES_FOLDER/Roddy/dist/bin/current/lib/RoddyToolLib.jar
	
RUN cd $RODDY_PLUGINS_R2_4 && git clone https://github.com/eilslabs/COWorkflowsBasePlugin COWorkflowsBasePlugin_1.0.0 && \
	cd COWorkflowsBasePlugin_1.0.0 && git checkout 1.0.0

## HINT: Run Roddy with: ~/binaries/Roddy/roddy.sh testrun coWorkflowsTestProject@aceseq [ALL] --c=/home/roddy/config/ini/alllocal.ini --vv
## HINT: 				 ~/binaries/Roddy/roddy.sh testrun coWorkflowsTestProject@aceseq stds --c=/home/roddy/config/ini/alllocal.ini
## HINT: 				 ~/binaries/Roddy/roddy.sh run coWorkflowsTestProject@aceseq stds --c=/home/roddy/config/ini/alllocal.ini
## HINT: Run the container with: docker run -v /home/heinold/.roddy/runtimeDevel/:/home/roddy/.roddy/runtimeDevel -v /home/heinold/temp:/home/roddy/temp -v `readlink -f config`:/home/roddy/config  -t -i aceseqimage /bin/bash

