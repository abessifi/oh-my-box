#!/bin/bash -eux

set -e

suse_common(){
	# remove zypper package locks
	rm -f /etc/zypp/locks
	# Install Python Installer Package
	zypper install -y gcc tar python-devel python-pip
}

debian_common(){
	# Install Python Installer Package
	apt-get -y update
	apt-get install -y sudo nano htop less curl build-essential libffi-dev libyaml-dev python-dev libssl-dev
	apt-get -y purge python-cffi
	# Install pip
	curl -sSL https://bootstrap.pypa.io/get-pip.py | python
}

el_common(){
	# Install Python Installer Package
	yum -y install sudo epel-release net-tools
	yum -y install gcc gcc-c++ patch libyaml-devel autoconf readline-devel zlib-devel libffi-devel openssl-devel automake libtool bison
	yum -y install nano htop less curl python-devel python-pip
}

setup(){

	# Grant 'sudo' to 'vargant' user
	if [ "$PACKER_PLATFROM_TYPE" = 'vagrant' ]; then
		# Add vagrant user to sudoers.
		echo "vagrant        ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers.d/vagrant
		chmod 440 /etc/sudoers.d/vagrant
	fi

	# Disable 'requiretty' when 'sudo' if called
	sed -i "s/^.*requiretty/#Defaults requiretty/" /etc/sudoers
	# Install Ansible
	yes | pip install httplib2 markupsafe ansible==$ANSIBLE_VERSION

}

# Do specific actions depending on distro type
case "$PACKER_DISTRO_TYPE" in
	opensuse|suse) suse_common;;
	debian|ubuntu) debian_common;;
	centos) el_common;;
	*) echo "[ERROR] Unknown PACKER_DISTRO_TYPE value";
	   exit 1;;
esac

setup
