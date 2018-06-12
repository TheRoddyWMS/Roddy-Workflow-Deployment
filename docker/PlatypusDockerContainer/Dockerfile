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
	wget -q https://repo.continuum.io/miniconda/Miniconda2-4.4.10-Linux-x86_64.sh && \
	echo "Install Anaconda" && \
	sudo bash Miniconda2-4.4.10-Linux-x86_64.sh -b -p /home/roddy/anaconda2 && \
	rm -rf Miniconda2-4.4.10-Linux-x86_64.sh && \
	echo Done && \
	export PATH=/home/roddy/anaconda2/bin/:$PATH

ENV PATH=/home/roddy/anaconda2/bin/:$PATH

RUN env; \
	conda config --add channels r; \
	conda config --add channels defaults; \
	conda config --add channels conda-forge; \
	conda config --add channels bioconda;

# Clone or download Roddy
# Clone or download IndelCallingWorkflow && COWorkflows Plugin, put them to the Roddy directory
# Create or add configuration files.

ENV BINARIES_FOLDER /home/roddy/binaries

ENV RODDY_PLUGINS_R2_4 $BINARIES_FOLDER/Roddy/plugins_R2.4

ENV RODDY_BASE_PLUGINS $BINARIES_FOLDER/Roddy/dist/plugins

ENV INDEL_CALLING_FOLDER $RODDY_PLUGINS_R2_4/IndelCallingWorkflow_1.2.177-2

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
	(cd DefaultPlugin && git checkout 951fc80) && \
	(cd PluginBase && git checkout 1.2.0) && \
	cp -r DefaultPlugin DefaultPlugin_1.2.0 &&  \
	cp -r PluginBase PluginBase_1.2.0

# Install Groovy 2.4.7 from Maven. OpenJDK is already installed in the base image so just link it..
RUN mkdir -p ~/.roddy/runtimeDevel && cd ~/.roddy/runtimeDevel && \
	groovyArchive=$(curl -s https://dl.bintray.com/groovy/maven/ 2>&1  | grep groovy | grep 2.4.7 | grep -v ".asc" | sed 's/href=":/\n/g' | sed 's/>/\n/g' | sed 's/</\n/g' | grep groovy | grep "binary"| grep -v "rel="  | grep -v "md5" | sort -V) && \
	groovyZipLink="https://dl.bintray.com/groovy/maven/"$(echo $groovyArchive | tail -n 1) && \
	wget $groovyZipLink && \
	unzip $groovyArchive && \
	rm $groovyArchive && \
	ln -sf /usr/lib/jvm/java-8-openjdk-amd64 ~/.roddy/runtimeDevel/jdk && ln -sf ~/.roddy/runtimeDevel/jdk ~/.roddy/runtimeDevel/jdk1.8.0_131

RUN cd $RODDY_PLUGINS_R2_4 && git clone https://github.com/eilslabs/COWorkflowsBasePlugin COWorkflowsBasePlugin_1.0.0 && \
	cd COWorkflowsBasePlugin_1.0.0 && git checkout 8c8a190

# Install the indel calling workflow
# the workflow needs to be imported to a temporary location first
# and then copied to the destination, because COPY imports files as owned by root
COPY IndelCallingWorkflow /tmp/import_indel_calling_workflow
RUN cp -r /tmp/import_indel_calling_workflow $INDEL_CALLING_FOLDER

# switch to branch compatible with given Roddy version
RUN cd $INDEL_CALLING_FOLDER && git checkout 18921ac && \
    sed -i -e 's/COWorkflows:[-.0-9]*/COWorkflowsBasePlugin:1.0.0/' -e 's/PluginBase:[-.0-9]*/PluginBase:1.2.0-0/' buildinfo.txt

# extract Conda config files from branch with Conda support and install packages from Conda
RUN CONDA_BRANCH=e794e08 && \
    cd $INDEL_CALLING_FOLDER/resources/analysisTools/indelCallingWorkflow/environments && \
    git show $CONDA_BRANCH:./conda.sh > conda.sh && chmod a+x conda.sh && \
    git show $CONDA_BRANCH:./conda.yml > conda.yml && \
    sed -i -e 's/r-purrr=.*/r-purrr=0.2.4/' conda.yml && \
    conda env create -n IndelCallingWorkflow -f conda.yml

RUN conda install -n IndelCallingWorkflow -y pypy2.7=5.10.0=0 perl-string-util=1.26=pl5.22.0_0 perl-number-misc=1.2=pl5.22.0_0 perl-test-toolbox=0.4=pl5.22.0_0

# import matplotlib once to build the font cache (fails inside a gridengine job, so we do it here)
RUN bash -c "source activate IndelCallingWorkflow && python -c import\\ matplotlib.pyplot"
