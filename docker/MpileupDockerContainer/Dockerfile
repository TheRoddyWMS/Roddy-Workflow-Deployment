FROM roddybaseimage_xenial1604
#FROM roddybaseimage:latest
MAINTAINER Michael Heinold @ DKFZ

USER roddy

# install utilities

RUN sudo apt-get update && sudo apt-get install -y bzip2 git curl

# locales need to be reconfigured or else Platypus complains
RUN sudo apt-get install -y locales && sudo locale-gen en_US.UTF-8

# Install Bioconda

RUN cd /home/roddy; \
	echo "Download Anaconda"; \
	wget -q https://repo.continuum.io/miniconda/Miniconda3-4.5.1-Linux-x86_64.sh && \
	echo "Install Anaconda" && \
	sudo bash Miniconda3-4.5.1-Linux-x86_64.sh -b -p /home/roddy/miniconda3 && \
	rm -rf Miniconda3-4.5.1-Linux-x86_64.sh && \
	echo Done && \
	export PATH=/home/roddy/miniconda3/bin/:$PATH

ENV PATH=/home/roddy/miniconda3/bin/:$PATH

RUN env; \
	conda config --add channels r; \
	conda config --add channels defaults; \
	conda config --add channels conda-forge; \
	conda config --add channels bioconda;

# Clone or download Roddy
# Clone or download SNVCallingWorkflow && COWorkflows Plugin, put them to the Roddy directory
# Create or add configuration files.

ENV BINARIES_FOLDER /home/roddy/binaries

ENV RODDY_PLUGINS_R2_4 $BINARIES_FOLDER/Roddy/plugins_R2.4

ENV RODDY_BASE_PLUGINS $BINARIES_FOLDER/Roddy/dist/plugins
ENV RODDY_LIBS $BINARIES_FOLDER/Roddy/dist/bin/current/lib

ENV SNV_CALLING_FOLDER $RODDY_PLUGINS_R2_4/SNVCallingWorkflow_1.2.166-1

ENV CO_WORKFLOWS_FOLDER $RODDY_PLUGINS_R2_4/COWorkflows_1.2.3-1

# Prepare the Roddy setup, also prepare Default and Base plugin
RUN mkdir -p $BINARIES_FOLDER && cd $BINARIES_FOLDER && \
	rm -rf $BINARIES_FOLDER/Roddy &&  \
	git clone https://github.com/eilslabs/Roddy.git &&  \
	cd Roddy &&  git checkout 3.0.7 &&  mkdir -p $RODDY_PLUGINS_R2_4 &&  \
	ls -l && \
	ls -l .git/ && \
	git submodule add -f  https://github.com/eilslabs/Roddy-Base-Plugin.git dist/plugins/PluginBase && \
	git submodule add -f  https://github.com/eilslabs/Roddy-Default-Plugin.git dist/plugins/DefaultPlugin && \
	cd $RODDY_BASE_PLUGINS &&  \
	ls -l && \
	(cd DefaultPlugin && git checkout 1.2.2-1) && \
	(cd PluginBase && git checkout 1.2.1 && sed -i -e 's/DefaultPlugin:[-.0-9]*/DefaultPlugin:1.2.2-1/' buildinfo.txt) && \
	cp -r DefaultPlugin DefaultPlugin_1.2.2-1 &&  \
	cp -r PluginBase PluginBase_1.2.1

# Install Groovy 2.4.7 from Maven. OpenJDK is already installed in the base image so just link it..
RUN mkdir -p ~/.roddy/runtimeDevel && cd ~/.roddy/runtimeDevel && \
	groovyArchive=$(curl -s https://dl.bintray.com/groovy/maven/ 2>&1  | grep groovy | grep 2.4.9 | grep -v ".asc" | sed 's/href=":/\n/g' | sed 's/>/\n/g' | sed 's/</\n/g' | grep groovy | grep "binary"| grep -v "rel="  | grep -v "md5" | sort -V) && \
	groovyZipLink="https://dl.bintray.com/groovy/maven/"$(echo $groovyArchive | tail -n 1) && \
	wget $groovyZipLink && \
	unzip $groovyArchive && \
	rm $groovyArchive && \
	ln -sf /usr/lib/jvm/java-8-openjdk-amd64 ~/.roddy/runtimeDevel/jdk && ln -sf ~/.roddy/runtimeDevel/jdk ~/.roddy/runtimeDevel/jdk1.8.0_131 && \
	mv ~/.roddy ~/.roddy.template # required for Singularity (will be copied to writable dir and symlinked)

RUN cd $BINARIES_FOLDER/Roddy && ./gradlew build && \
    cd dist/bin && ln -sf develop 3.0.7 && ln -sf develop current

RUN cd $RODDY_PLUGINS_R2_4 && git clone https://github.com/eilslabs/COWorkflowsBasePlugin COWorkflowsBasePlugin_1.0.2 && \
	cd COWorkflowsBasePlugin_1.0.2 && git checkout 1.0.2

# Update BatchEuphoria to a version compatible with SGE
RUN wget -qO - https://github.com/TheRoddyWMS/BatchEuphoria/releases/download/0.0.3/BatchEuphoria-0.0.3.jar > $RODDY_LIBS/BatchEuphoria-0.0.2.jar
RUN wget -qO - https://github.com/TheRoddyWMS/RoddyToolLib/releases/download/0.0.4/RoddyToolLib-0.0.4.jar > $RODDY_LIBS/RoddyToolLib-0.0.3.jar

# Install the SNV calling workflow
# the workflow needs to be imported to a temporary location first
# and then copied to the destination, because COPY imports files as owned by root
COPY SNVCallingWorkflow /tmp/import_SNVCallingWorkflow
RUN cp -r /tmp/import_SNVCallingWorkflow $SNV_CALLING_FOLDER && \
    cd $SNV_CALLING_FOLDER && git checkout e28c25d && \
    sed -i -e 's/COWorkflows:[-.0-9]*/COWorkflows:1.2.3-1/' buildinfo.txt
COPY COWorkflows /tmp/import_COWorkflows
RUN cp -r /tmp/import_COWorkflows $CO_WORKFLOWS_FOLDER && \
    cd $CO_WORKFLOWS_FOLDER && git checkout 1.2.3-1 && \
    sed -i -e 's/PluginBase:[-.0-9]*/PluginBase:1.2.1/' buildinfo.txt

# install Conda packages
COPY conda.yml $SNV_CALLING_FOLDER/resources/analysisTools/snvPipeline/environments/conda.yml
RUN conda env create -n SNVCallingWorkflow -f $SNV_CALLING_FOLDER/resources/analysisTools/snvPipeline/environments/conda.yml

# copy workflow config
COPY config /home/roddy/config
