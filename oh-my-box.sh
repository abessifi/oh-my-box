#!/bin/bash

# ---------------------------------------------------------------------
# Copyright (C) 2016  Ahmed Bessifi
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------
#
# DESCRIPTION:
#   This shell script can be used to prepare some vagrant boxes (based on other
#   minimal iso images). The idea is to create and provision a minimal image with
#   Packer and Asible then package it to a Vagrant box.
#
# REQUIREMENTS:
#   - Virtualbox (tested with 5.0)
#   - Packer (>= v0.8.6)
#   - Vagrant (tested with v1.7)
#
# USAGE:
#   $ ./oh-my-box.sh [options]
#
#   After provisioning and packaging, new Vagrant boxes are generated:
#
#	  <system_username>/debian-jessie-ansible
#	  <system_username>/centos-7.1-ansible
#
#

set -e

SYSTEM_USER=$(whoami)

DEFAULT_DEBIAN_BASIC_BOX="${SYSTEM_USER}/debian-jessie-ansible"
DEFAULT_UBUNTU_BASIC_BOX="${SYSTEM_USER}/ubuntu-trusty-ansible"
DEFAULT_CENTOS_BASIC_BOX="${SYSTEM_USER}/centos-7.1-ansible"
DEFAULT_OPENSUSE_BASIC_BOX="${SYSTEM_USER}/opensuse-13.2-ansible"
DEFAULT_SLES_BASIC_BOX="${SYSTEM_USER}/sles-11sp3-ansible"

REMOVE_BASIC_BOX=false
OVERWRITE_EXISTING_BOX=false

usage(){

	echo "
Usage: $0 [options]

Options:
    -c, --centos     Prepare a CentOS box
    -d, --debian     Prepare a Debian box
    -o, --opensuse   Prepare an OpenSUSE box
    -s, --sles       Prepare a SLES box
    -u, --ubuntu     Prepare a Ubuntu box
    -x, --clean      Remove basic vagrant box after building new one
    -f, --force      Overwrite an existing box
    -h, --help       Show this help message and exit
	"
	exit 1
}

# NOTE: VirtualBox, Packer and Vagrant versions aren't checked.
# Please make sure you are using supported versions as mentioned
# above on script doc (REQUIREMENTS section).
is_installed(){
	# If failure, don't return immediately;
	# Check requirements once for all.
	ret_code=0

	for tool_name in $@; do
		if [ ! `which $tool_name` ]
		then
			logger "ERROR" "'$tool_name' is not installed !"
			ret_code=1
		fi
	done
	
	return $ret_code
}

get_vboxver() {
	vboxmanage --version | sed 's#^\(\([0-9]\.\?\)*[0-9]\).*#\1#'
}

get_packerver() {
	packer --version
}

get_vagrantver() {
	vagrant --version | cut -d ' ' -f2
}

# Reconize numeric-dotted format only.
isver() {
	if [ $# -ne 1 ]
	then
		echo "usage: isver version"
		exit 1
	fi

	echo -n "$1" | grep -c '^\([0-9]\.\?\)*[0-9]$'
}

vcmp() {
	if [ $# -ne 2 ]
	then
		echo "usage: $0 v1 v2"
		exit 1
	fi
	if [ `isver "$1"` -eq 0 -o `isver "$2"` -eq 0 ]
	then
		echo "bad version number."
		exit 2
	fi
	
	ver_sort=`echo -e "$1\n$2" | sort -V`
	vcmp_ret=2 # v1>v2
	if [ `echo "$ver_sort" | uniq -d | wc -l` -eq 1 ]
	then
		vcmp_ret=1 # v1=v2
	elif [ `echo "$ver_sort" | head -1` = "$1" ]
	then
		vcmp_ret=0 # v1<v2
	fi
	
	echo $vcmp_ret
}

requirements_met() {
	packer_ver=`get_packerver`
	vagrant_ver=`get_vagrantver`
	vbox_ver=`get_vboxver`
	
	ret_code=0
	if [ `vcmp "$packer_ver" "0.8.6"` -lt 1 ]
	then
		logger "ERROR" "Requirement: Packer: ver. \`($packer_ver >= 0.8.6)' failed."
		ret_code=1
	fi
	if [ `vcmp "$vagrant_ver" "1.7"` -lt 1 ]
	then
		logger "ERROR" "Requirement: Vagrant: ver. \`($vagrant_ver >= 1.7)' failed."
		ret_code=1
	fi
	if [ `vcmp "$vbox_ver" "5.0"` -lt 1 ]
	then
		logger "WARN" "Recommanded: Virtualbox: ver. \`($vbox_ver >= 5.0)' failed."
	fi
	
	return $ret_code
}

setup(){
	# Check tools existance
	is_installed 'VirtualBox' 'packer' 'vagrant' || exit $?
	requirements_met || exit $?
}

teardown(){
	true
}

logger(){
	# Log actions/messages to stdout
	log_level=$1
	log_msg=$2
	NC='\033[0m' # No Color
	case "$log_level" in
		INFO|info)
			msg_color='\033[0;32m';;
		WARN|warn)
			msg_color='\033[1;33m';;
		ERROR|error)
			msg_color='\033[0;31m';;
		*)
			msg_color='\033[1;37m';;
	esac

	echo -e "${msg_color}[$log_level] $log_msg ${NC}"
}

build_box(){

	box_name=$1
	box_os_type=$2

	logger "INFO" "Start creating '${box_name}' with Packer..."

	# Build the Vagrant box image with Packer
	(cd ./packer/; packer build `ls ${box_os_type}_*.json`)

	# Add the new created box
	vagrant box add --force $box_name ./packer/builds/packer_${box_os_type}_*_amd64_virtualbox.box
	# Remove generated .box file if '--clean' option is specified
	if [ "$REMOVE_BASIC_BOX" = "true" ]; then
		logger "INFO" "Clearing temporaty files..."
		rm -rf ./packer/builds/packer_${box_os_type}_*_amd64_virtualbox.box
	fi

	logger "INFO" "'$box_name' box is created !"
}

checkout_box(){
	vagrant_box=$1
	vagrant_box_os_type=$2
	# Check for Packer template
	find ./packer/${vagrant_box_os_type}_*.json &> /dev/null || ( logger "WARN" "'${vagrant_box_os_type}' distribution not yet supported !" && exit 1)
	# Get basic box name
	if [ -z $(echo "$vagrant_box" | cut -d'/' -f1) ]; then
		vagrant_box_name="$vagrant_box"
		vagrant_box_owner=$(whoami)
	else
		vagrant_box_owner=$(echo "$vagrant_box" | cut -d'/' -f1)
		vagrant_box_name=$(echo "$vagrant_box" | cut -d'/' -f2)
	fi

	box_name="${vagrant_box_owner}/${vagrant_box_name}"

	# Check if the box is already added download/build it otherwise.
	logger "INFO" "Check for box '${box_name}'"
	if [ $(vagrant box list | grep -c "${box_name}") -eq 0 ]; then
		logger "INFO" "Try downloading '$box_name' box..."
	else
		logger "WARN" "Box '${box_name}' exists already."
		[ "$OVERWRITE_EXISTING_BOX" = "false" ] && exit 0
	fi
	vagrant box add $box_name 2> /dev/null || build_box $box_name $vagrant_box_os_type
}

#
# main()
#

# Print help and Exit if not option is specified
[ $# -eq 0  ] && usage

# Execute getopt
ARGS=$(getopt -o c::d::o::s::u::xfh -l "centos::,debian::,opensuse::,sles::,ubuntu::,clean,force,help" -n "$0" -- "$@") || usage
eval set -- "$ARGS"

distros=()

# Loop over different options and set some variables.
while true; do
    case "$1" in
		-c|--centos)
			shift
			distros+=('CENTOS')
			[ -n "$1" ] && CENTOS_BASIC_BOX="$1" || CENTOS_BASIC_BOX="$DEFAULT_CENTOS_BASIC_BOX"
			shift;;
		-d|--debian)
			shift
			distros+=('DEBIAN')
			[ -n "$1" ] && DEBIAN_BASIC_BOX="$1" || DEBIAN_BASIC_BOX="$DEFAULT_DEBIAN_BASIC_BOX"
			shift;;
		-o|--opensuse)
			shift
			distros+=('OPENSUSE')
			[ -n "$1" ] && OPENSUSE_BASIC_BOX="$1" || OPENSUSE_BASIC_BOX="$DEFAULT_OPENSUSE_BASIC_BOX"
			shift;;
		-s|--sles)
			shift
			distros+=('SLES')
			[ -n "$1" ] && SLES_BASIC_BOX="$1" || SLES_BASIC_BOX="$DEFAULT_SLES_BASIC_BOX"
			shift;;
		-u|--ubuntu)
			shift
			distros+=('UBUNTU')
			[ -n "$1" ] && UBUNTU_BASIC_BOX="$1" || UBUNTU_BASIC_BOX="$DEFAULT_UBUNTU_BASIC_BOX"
			shift;;
        -x|--clean)
            REMOVE_BASIC_BOX=true
            shift;;
        -f|--force)
            OVERWRITE_EXISTING_BOX=true
            shift;;
        -h|--help)
            usage
            ;;
        --)
			shift
            break;;
    esac
done

# Call setup() function
setup

# Loop over the basic distros and build new boxes
for os in ${distros[@]}; do
	vagrant_box="${os}_BASIC_BOX"
	checkout_box ${!vagrant_box} $(echo $os | awk '{ print tolower($0) }')
done

# Call teardown() function
teardown

# vim: set ts=4 sw=4 noet:
