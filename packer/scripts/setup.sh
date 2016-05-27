#!/bin/bash -eux

suse_common(){
	# remove zypper package locks
	rm -f /etc/zypp/locks
	# Install Python Installer Package
	zypper install -y gcc tar python-devel python-pip
}

debian_common(){
	# Install Python Installer Package
	apt-get -y update
	apt-get install -y sudo python-dev python-pip
}

el_common(){
	# Install Python Installer Package
	yum -y install epel-release net-tools
	yum -y install gcc gcc-c++ patch libyaml-devel autoconf readline-devel zlib-devel libffi-devel openssl-devel automake libtool bison
	yum -y install nano htop less python-devel python-pip
}

if [ "$PACKER_PLATFROM_TYPE" -eq 'vagrant' ]; then
	# Add vagrant user to sudoers.
	echo "vagrant        ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers.d/vagrant
	chmod 440 /etc/sudoers.d/vagrant
	sed -i "s/^.*requiretty/#Defaults requiretty/" /etc/sudoers
fi

# Do specific actions depending on distro type
case "$PACKER_DISTRO_TYPE" in
	opensuse|suse) suse_common;;
	debian|ubuntu) debian_common;;
	centos) el_common;;
	*) echo "[ERROR] Unknown PACKER_DISTRO_TYPE value";
	   exit 1;;
esac

# Install Ansible
yes | pip install httplib2 markupsafe ansible==$ANSIBLE_VERSION

