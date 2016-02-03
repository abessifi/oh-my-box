`Oh-My-Box` is a set of [Packer](www.packer.io) templates, [Ansible](www.ansible.com) playbooks and Shell scripts which can be used to prepare a bunch of [Vagrant](www.vagrantup.com) boxes (based on other GNU/Linux minimal images). The created boxes can be used, for example, to develop and test Ansible roles on different `GNU/Linux` distributions. Yes, Ansible roles compatibility matters !

## Description

For instance, the idea may be to prepare a basic vagrant boxes with specific `Ansible` and stable `Ruby` versions which can be used, for example, to run [test-kitchen](http://kitchen.ci):

- Create a virtual environment
- Install the Ansible role to be tested
- Run Ansible to provision the target environment
- Run all acceptance tests (using [serverspec](http://serverspec.org/) for instance)

`Oh-My-Box` uses Packer and Vagrant tools to:

- Download a minimal image
- Create a virtual machine (Actually, only Virtualbox is supported)
- Provision it using Ansible ;)
- Package the VM to a new Vagrant box
- Add/Push the new created box to the Vagrant local/remote repository

## Requirements

- Virtualbox (tested with 5.0)
- Packer (>= v0.8.6)
- Vagrant (>= v1.7)
- Ansible (tested with v1.9)

## Usage

Run the script `oh-my-box.sh` which gets the basic vagrant boxes names to provision from the script arguments:

	$ ./oh-my-box.sh [options]

After provisioning the VMs with specific Ansible and Ruby versions, the script generates new vagrant boxes:

	debian/jessie64   =>  <system_username>/jessie64-ansible
	bento/centos-7.1  =>  <system_username>/centos-7.1-ansible

### Options

    -c, --centos     Prepare a CentOS box
    -d, --debian     Prepare a Debian box
    -o, --opensuse   Prepare an OpenSUSE box
    -s, --sles       Prepare a SLES box
    -u, --ubuntu     Prepare a Ubuntu box
    -x, --clean      Remove basic vagrant box after building the new one
    -h, --help       Show this help message and exit

### Examples

Create new boxes for Debian, Ubuntu and CentOS distributions. Default boxes corresponding to each system will be used (see DEFAULT_*_BASIC_BOX variables in the `oh-my-box.sh` script):

	$ ./oh-my-box.sh --centos --debian --ubuntu

Create new Debian box based on `foobar/debian-8.2` vagrant box (and don't keep it):

	(baz)$ ./oh-my-box.sh -x --debian=foobar/debian-8.2
	(baz)$ vagrant box list

	baz/debian-8.2-ansible    (virtualbox, 0)


Here is an example of the script output:

```
[INFO] debian-8.2-ansible | Init Vagrantfile
[INFO] debian-8.2-ansible | Starting and provisioning...
Bringing machine 'default' up with 'virtualbox' provider...
==> default: Box 'foobar/debian-8.2' could not be found. Attempting to find and install...
    default: Box Provider: virtualbox
    default: Box Version: >= 0
==> default: Loading metadata for box 'foobar/debian-8.2'
...
...
[INFO] debian-8.2-ansible | Packaging...
==> default: Attempting graceful shutdown of VM...
==> default: Clearing any previously set forwarded ports...
==> default: Exporting VM...
...
==> box: Successfully added box 'abessifi/centos-7.1-ansible' (v0) for 'virtualbox'!
[INFO] debian-8.2-ansible | Cleaning...
==> default: Destroying VM and associated drives...
==> default: Running cleanup tasks for 'ansible' provisioner...
...
[INFO] baz/debian-8.2-ansible created !
```

