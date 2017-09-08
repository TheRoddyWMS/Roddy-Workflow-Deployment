#!/bin/bash

if [[ ! -d commondependencies ]]
then
	(
		mkdir commondependencies
		cd commondependencies
		ln -sf ../../commondependencies/* .
		tar -xvzf `ls jre*.tar.gz`
		unzip `ls apache-groovy*.zip`
	)
fi


