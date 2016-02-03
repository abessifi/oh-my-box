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
#   vagrant boxes) to develop and test Ansible roles on different GNU/Linux
#   distributions. Yes, Ansible roles compatibility matters !
#
#   The idea is to prepare basic vagrant boxes with specific Ansible
#   and ruby versions, which can be used, for example, to run test-kitchen (see http://kitchen.ci):
#     - Create a virtual environment
#     - Install the Ansible role to be tested
#     - Run ansible to provision the target environment
#     - Run all acceptance tests (using serverspec for instance)
#
# NOTE:
#   We use vagrant tool to:
#     - Download basic boxes
#     - Create virtual environments
#     - Provision them using Ansible ;)
#     - Package new boxes
#     - Add new created boxes to the vagrant 'local repository'
#
# REQUIREMENTS:
#   - Virtualbox (tested with 5.0)
#   - Vagrant (tested with v1.7)
#   - Ansible (tested with v1.9)
#
# USAGE:
#   The script gets the basic vagrant boxes name, to provision from the commande, as arguments:
#   $ ./oh-my-box.sh -x --debian=foo/bar
#
#   After provisioning the VMs with specific Ansible and Ruby versions, the script generates
#   new vagrant boxes named respectively to the input boxes name. E.g:
#     debian/jessie64  => <system_username>/jessie64-ansible
#     bento/centos-7.1 => <system_username>/centos-7.1-ansible
#

set -e

DEFAULT_DEBIAN_BASIC_BOX='debian/jessie64'
DEFAULT_UBUNTU_BASIC_BOX='ubuntu/trusty64'
DEFAULT_CENTOS_BASIC_BOX='bento/centos-7.1'
DEFAULT_OPENSUSE_BASIC_BOX='bento/opensuse-13.2'
DEFAULT_SLES_BASIC_BOX='suse/sles11sp3'

WORKING_DIR="./.tmp/"
REMOVE_BASIC_BOX=false

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
    -h, --help       Show this help message and exit
	"
	exit 1
}

# NOTE: VirtualBox, Vagrant and Ansible versions aren't checked.
# Please make sure you are using supported versions as mentioned
# above on script doc (REQUIREMENTS section).
is_installed(){

	for tool_name in $@; do
		[ `which $tool_name` ] || echo "'$tool_name' is not installed !" || exit 1
	done
}

setup(){
	# Check tools existance
	is_installed 'VirtualBox' 'vagrant' 'ansible'
	# Create temporary working directory
	mkdir -p $WORKING_DIR
	# Clean up the working directory if it exists already
	rm -rf "${WORKING_DIR}/*"
}

teardown(){
	# Remove the temporary working directory
	rm -rf $WORKING_DIR
}

logger(){
	# Log actions/messages to stdout
	log_level=$1
	log_msg=$2
	NC='\033[0m' # No Color
	case "$log_level" in
		INFO)
			msg_color='\033[0;32m';;
		WARN)
			msg_color='\033[1;33m';;
		ERROR)
			msg_color='\033[0;31m';;
		*)
			msg_color='\033[1;37m';;
	esac

	echo -e "${msg_color}[$log_level] $log_msg ${NC}"
}

build_new_box(){
	vagrant_basic_box=$1
	# Get basic box name
	if [ -z $(echo "$vagrant_basic_box" | cut -d'/' -f1) ]; then
		basic_box_name="$vagrant_basic_box"
	else
		basic_box_owner=$(echo "$vagrant_basic_box" | cut -d'/' -f1)
		basic_box_name=$(echo "$vagrant_basic_box" | cut -d'/' -f2)
	fi

    new_box_owner=$(whoami)
	new_box_name="${new_box_owner}/${basic_box_name}-ansible"

	# Init a Vagrantfile
	logger "INFO" "${basic_box_name}-ansible | Init Vagrantfile"
	sed "s,foo/bar,$vagrant_basic_box,g" files/Vagrantfile.template > ${WORKING_DIR}/Vagrantfile
	cp -a ansible/ ${WORKING_DIR}/
	# Change to the temporary working directory
	cd $WORKING_DIR
	# Download the basic box, start and provision it
	logger "INFO" "${basic_box_name}-ansible | Starting and provisioning..."
	vagrant up --provision
	# Package the new box after provisioning
	logger "INFO" "${basic_box_name}-ansible | Packaging..."
	vagrant package --output "${basic_box_name}-ansible.box"
	# Add the new created box
	vagrant box add --force $new_box_name "${basic_box_name}-ansible.box"
	# Clean the working directory
	logger "INFO" "${basic_box_name}-ansible | Cleaning..."
	vagrant destroy --force
	rm -f Vagrantfile "${basic_box_name}-ansible.box"
    [ "$REMOVE_BASIC_BOX" = "true" ] && vagrant box remove $vagrant_basic_box
	# Quit the current temporary working directory
	cd -
	logger "INFO" "$new_box_name created !"
}

#
# main()
#

# Print help and Exit if not option is specified
[ $# -eq 0  ] && usage

# Execute getopt
ARGS=$(getopt -o c::d::o::s::u::xh -l "centos::,debian::,opensuse::,sles::,ubuntu::,clean,help" -n "$0" -- "$@") || usage
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
	build_new_box ${!vagrant_box}
done

# Call teardown() function
teardown
