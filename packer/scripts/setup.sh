#!/bin/bash -eux

# Add vagrant user to sudoers.
echo "vagrant        ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers.d/vagrant
chmod 440 /etc/sudoers.d/vagrant
sed -i "s/^.*requiretty/#Defaults requiretty/" /etc/sudoers

# Install Python Installer Package
apt-get -y update
apt-get install -y sudo python-dev python-pip

# Install Ansible
yes | pip install markupsafe ansible==$ANSIBLE_VERSION
