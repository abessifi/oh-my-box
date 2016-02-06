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

common_actions(){
	# Add vagrant user to sudoers.
	echo "vagrant        ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers.d/vagrant
	chmod 440 /etc/sudoers.d/vagrant
	sed -i "s/^.*requiretty/#Defaults requiretty/" /etc/sudoers

	# Install Ansible
	yes | pip install markupsafe ansible==$ANSIBLE_VERSION
}

case "$PACKER_DISTRO_TYPE" in
	opensuse) suse_common;;
	suse) suse_common;;
	debian) debian_common;;
	ubuntu) debian_common;;
	*) echo "[ERROR] Unknown PACKER_DISTRO_TYPE value";
	   exit 1;;
esac

common_actions
