FROM ubuntu:xenial
MAINTAINER Michael Heinold @ DKFZ

ENV home /home/roddy
ENV binaries /home/roddy/binaries
ENV scratch /data/roddyScratch
ENV runtime $home/.roddy/runtimeDevel
ENV DEBIAN_FRONTEND noninteractive

# Set hostname to master and
# add a host entry for localhost to set it to master. Necessary for SGE
ENV HOSTNAME master
RUN echo '127.0.0.1 master' | cat - /etc/hosts > /tmp/tmp_host && cp /tmp/tmp_host /etc/hosts

# Install all kinds of tools and packages
RUN apt-get update && \
    apt-get -y install apt-utils apt-transport-https; \
    apt-get -y install tabix procmail zip make cpanminus python-dev python-pip less \
					   libgfortran3 libglu1-mesa-dev wget libfreetype6 libfreetype6-dev libpng-dev libcurl4-openssl-dev \
					   gfortran libcairo2 libjpeg-dev ghostscript vim sudo bsdmainutils aptitude \
					   gtk2-engines libxtst6 libxxf86vm1 freeglut3 libxslt1.1 \
					   python-gi-cairo openjdk-8-jdk gosu;

RUN cpanm XML::Parser --notest &&  \
    cpanm Math::CDF --notest

RUN	pip install python-dateutil && \
    easy_install -U 'distribute';


# Install the SGE
ADD scripts/gridEngineSetup.sh $binaries/gridEngineSetup.sh

ADD scripts/gridEngineConfiguration.txt $binaries/gridEngineConfiguration.txt

RUN	[ "/bin/bash" , "-c" , "ls -l $binaries; source /home/roddy/binaries/gridEngineSetup.sh; setupHost; installGridEngine; setupGridEngine;"  ]


# Create all kinds of directories for Roddy and projects
# Add the Roddy user and bash things
RUN mkdir -p /home/roddy/workspace && \
    mkdir -p /home/roddy/.roddy/runtimeDevel && \
    mkdir -p /home/roddy/binaries && \
    mkdir -p /data/roddyScratch && \
    mkdir -p /icgc/ngs_share && \
    useradd roddy -d /home/roddy && \
    chown -R roddy:roddy /home/roddy/workspace && \
    chown -R roddy:roddy /home/roddy && \
    chown -R roddy:roddy /data/roddyScratch && \
    chown -R roddy:roddy /icgc && \
    chmod -R 777 /data/roddyScratch && \
    chmod 777 /home/roddy /dev/stdout /dev/stderr && \
    adduser roddy sudo && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER roddy

ADD BASHRC /home/roddy/.bashrc

#ADD commondependencies /home/roddy/temporary

#RUN sudo chown -R roddy:roddy /home/roddy/temporary && \
#    sudo chmod -R 777 /home/roddy/temporary && \
#    sudo chmod -R 777 /icgc && \
#    cd /home/roddy/temporary && \
#    (unzip Roddy.zip && rm Roddy.zip && mv Roddy $binaries) && \
#    (unzip `ls apache-groovy*zip` && rm apache-groovy*.zip && mv groovy* $runtime) && \
#    sudo chmod -R +x /home/roddy/binaries/Roddy/dist/plugins

#    rm -rf /home/roddy/temporary && \
#    (tar -xvz --file=`ls j*` && rm j*.gz && mv j* $runtime) && \

ADD ENTRYPOINT.sh /ENTRYPOINT.sh

USER root

RUN chmod 777 /ENTRYPOINT.sh

# Singularity requires images to be read-only.
# => Move all writable directories aside.
# At runtime we mount a scratch dir from the host and copy these directories there.
# Using a symlink we point to the new location in the scratch dir.
RUN mkdir /home/roddy/writable.template && chmod a+rwx /home/roddy/writable.template && \
    mv /var/spool/gridengine /home/roddy/writable.template/var_spool_gridengine && \
    ln -s /home/roddy/writable/var_spool_gridengine /var/spool/gridengine && \
    mv /etc/gridengine/bootstrap /home/roddy/writable.template/etc_gridengine_bootstrap && \
    ln -s /home/roddy/writable/etc_gridengine_bootstrap /etc/gridengine/bootstrap && \
    mv /var/lib/gridengine/default/common /home/roddy/writable.template/var_lib_gridengine && \
    ln -s /home/roddy/writable/var_lib_gridengine /var/lib/gridengine/default/common && \
    mv /var/run/gridengine /home/roddy/writable.template/var_run_gridengine && \
    ln -s /home/roddy/writable/var_run_gridengine /var/run/gridengine

# passwd and group files need to be updated at runtime to give roddy the same ID as the calling user
RUN chmod a+rw /etc /etc/passwd /etc/group

USER roddy

ENTRYPOINT ["/ENTRYPOINT.sh"]

