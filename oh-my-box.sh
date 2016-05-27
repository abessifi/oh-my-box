#!/bin/bash

# vim: set ts=4 sw=4 noet:

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
#   This shell script can be used to prepare some vagrant/docker boxes/images (based on other
#   minimal images). The idea is to create and provision a minimal image with
#   Packer and Asible then package it to a Vagrant/docker box/image.
#
# REQUIREMENTS:
#   - Virtualbox (tested with 5.0)
#   - Packer  ( >= v0.8.6 )
#   - Vagrant ( >= v1.7 )
#   - Docker  ( >= v1.10 )
#
# USAGE:
#   $ ./oh-my-box.sh [options]
#
#   After provisioning and packaging, new Vagrant/Docker boxes/images are generated:
#
#	  <system_username>/debian-jessie-ansible
#	  <system_username>/centos-7.1-ansible
#
#

set -e

SYSTEM_USER=$(whoami)

# Default Vagrant base boxex
DEFAULT_DEBIAN_BASIC_BOX="${SYSTEM_USER}/debian-jessie-ansible"
DEFAULT_UBUNTU_BASIC_BOX="${SYSTEM_USER}/ubuntu-trusty-ansible"
DEFAULT_CENTOS_BASIC_BOX="${SYSTEM_USER}/centos-7.1-ansible"
DEFAULT_OPENSUSE_BASIC_BOX="${SYSTEM_USER}/opensuse-13.2-ansible"
DEFAULT_SLES_BASIC_BOX="${SYSTEM_USER}/sles-11sp3-ansible"

# Default Docker base images
DEFAULT_CENTOS_BASIC_IMG='centos:7'

REMOVE_BASIC_BOX=false
OVERWRITE_EXISTING_ARTIFACT=false

SUPPORTED_BUILD_PLATFORMS=(vagrant docker)
# Prepare a vagrant box by default (if --platform option is not set).
BUILD_PLATFORM="vagrant"

usage(){

	echo "
Usage: $0 [options]

Options:
    -c, --centos     Prepare a CentOS box
    -d, --debian     Prepare a Debian box
    -o, --opensuse   Prepare an OpenSUSE box
    -s, --sles       Prepare a SLES box
    -u, --ubuntu     Prepare a Ubuntu box
    -p, --platform   [vagrant|docker]
                     Prepare a box/image for Vagrant or Docker tools
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

get_dockerver() {
	docker --version | awk -F'[ ,]' '{ print $3 }'
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
	docker_ver=`get_dockerver`

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

	if [ `vcmp "$docker_ver" "1.10"` -lt 1 ]
	then
		logger "ERROR" "Requirement: Docker: ver. \`($docker_ver >= 1.10)' failed."
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

build_vagrant_box(){

	box_name=$1
	box_os_type=$2

	logger "INFO" "Start creating '${box_name}' with Packer..."

	# Build the Vagrant box image with Packer
	(cd ./packer/; packer build `ls vagrant_${box_os_type}_*.json`)

	# Add the new created box
	vagrant box add --force $box_name ./packer/builds/packer_${box_os_type}_*_amd64_virtualbox.box
	# Remove generated .box file if '--clean' option is specified
	if [ "$REMOVE_BASIC_BOX" = "true" ]; then
		logger "INFO" "Clearing temporaty files..."
		rm -rf ./packer/builds/packer_${box_os_type}_*_amd64_virtualbox.box
	fi

	logger "INFO" "'$box_name' box is created !"
}

artifact_name_format(){

	artifact=$1

    # Get the tag name if the artifact is a Docker image
	if [ "$BUILD_PLATFORM" = 'docker' ]; then
		if [ -z $(echo "$artifact" | awk -F':' '{print $2}') ]; then
			artifact_tag='latest'
		else
			artifact_tag=$(echo "$artifact" | cut -d':' -f2)
			artifact=$(echo "$artifact" | cut -d':' -f1)
		fi
	fi

	# Get basic artifact name
	if [ -z $(echo "$artifact" | awk -F'/' '{print $2}') ]; then
		artifact_name="$artifact"
		artifact_owner=$(whoami)
	else
		artifact_owner=$(echo "$artifact" | cut -d'/' -f1)
		artifact_name=$(echo "$artifact" | cut -d'/' -f2)
	fi

	# Return the full artifact name
	if [ "$BUILD_PLATFORM" = 'docker' ]; then
		echo "${artifact_owner}/${artifact_name}:${artifact_tag}"
	elif [ "$BUILD_PLATFORM" = 'vagrant' ]; then
		echo "${artifact_owner}/${artifact_name}"
	fi
}

checkout_vagrant_box(){

	vagrant_box=$1
	box_os_type=$2

	# Check for Packer template
	find ./packer/vagrant_${box_os_type}_*.json &> /dev/null || ( logger "WARN" "'$vagrant_box' distribution not yet supported !" && exit 1)

    box_name=$(artifact_name_format $vagrant_box)

	# Check if the box is already added download/build it otherwise.
	logger "INFO" "Check for box '${box_name}'"
	if [ $(vagrant box list | grep -c "${box_name}") -eq 0 ]; then
		logger "INFO" "Try downloading '$box_name' box..."
	else
		logger "WARN" "Box '${box_name}' exists already."
		[ "$OVERWRITE_EXISTING_ARTIFACT" = "false" ] && exit 0
	fi

	vagrant box add $box_name 2> /dev/null || build_vagrant_box $box_name $box_os_type
}

checkout_docker_image(){

	docker_img=$1
	img_os_type=$2

	# Check for Packer template
	find ./packer/docker_${img_os_type}_*.json &> /dev/null || ( logger "WARN" "'$docker_img' distribution not yet supported !" && exit 1)

	img_name=$(artifact_name_format $docker_img)

    # Check if the box is already added download/build it otherwise.
	if [ $(docker images --quiet ${img_name} | wc -l) -eq 0 ]; then
		logger "INFO" "Try downloading '$img_name' image..."
	else
		logger "WARN" "Image '${img_name}' exists already."
		[ "$OVERWRITE_EXISTING_ARTIFACT" = "false" ] && exit 0
	fi

	logger "INFO" "Start creating '${img_name}' with Packer..."

	# Build the Vagrant box image with Packer
	(cd ./packer/; packer build `ls docker_${img_os_type}_*.json`)

}

check_supported_build_platforms(){

	if [[ ! ${SUPPORTED_BUILD_PLATFORMS[*]} =~ "$1" ]]; then
		logger "ERROR" "'$1' is not a supported platform !"
		usage
	else
		BUILD_PLATFORM="${1}"
	fi
}

#
# main()
#

# Print help and Exit if not option is specified
[ $# -eq 0  ] && usage

# Execute getopt
ARGS=$(getopt -o c::d::o::s::u::p:xfh -l "centos::,debian::,opensuse::,sles::,ubuntu::,platform:,clean,force,help" -n "$0" -- "$@") || usage
eval set -- "$ARGS"

distros=()

# Loop over different options and set some variables.
while true; do
    case "$1" in
		-c|--centos)
			shift
			distros+=('CENTOS')
			[ -n "$1" ] && CENTOS_BASIC_BOX="$1" || CENTOS_BASIC_BOX="$DEFAULT_CENTOS_BASIC_BOX"
			[ -n "$1" ] && CENTOS_BASIC_IMG="$1" || CENTOS_BASIC_IMG="$DEFAULT_CENTOS_BASIC_IMG"
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
		-p|--platform)
			case "$2" in
				"") usage;;
				*) check_supported_build_platforms $2
					shift 2;;
			esac;;
        -x|--clean)
            REMOVE_BASIC_BOX=true
            shift;;
        -f|--force)
            OVERWRITE_EXISTING_ARTIFACT=true
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

	if [ "$BUILD_PLATFORM" = 'vagrant' ]; then
		vagrant_box="${os}_BASIC_BOX"
		checkout_vagrant_box ${!vagrant_box} $(echo $os | awk '{ print tolower($0) }')
    elif [ "$BUILD_PLATFORM" = 'docker' ]; then
		docker_img="${os}_BASIC_IMG"
		checkout_docker_image ${!docker_img} $(echo $os | awk '{ print tolower($0) }')
    fi

done

# Call teardown() function
teardown

