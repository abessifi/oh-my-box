## Description

`Oh-My-Box` is a set of [Packer](www.packer.io) templates, [Ansible](www.ansible.com) playbooks and Shell scripts which can be used to prepare a bunch of [Vagrant](www.vagrantup.com) boxes (based on a minimal GNU/Linux images). `Oh-My-Box` uses Packer and Vagrant tools to:

- Download a minimal image
- Create a virtual machine (Actually, only Virtualbox provider is supported)
- Provision it using Ansible
- Package the VM to a new Vagrant box
- Add the new created box to the Vagrant local repository

## Requirements

- Virtualbox (tested with 5.0)
- Packer (>= v0.8.6)
- Vagrant (>= v1.7)

## Test case

The created boxes can be used, for example, to develop and test Ansible roles on different `GNU/Linux` distributions. Yes, Ansible roles compatibility matters !
For instance, the idea may be to prepare a basic Vagrant boxes with specific `Ansible` and `Ruby` versions which can be used, for example, to run acceptance tests against the Ansible role using [test-kitchen](http://kitchen.ci):

- Create a virtual environment
- Install the Ansible role to be tested
- Run Ansible to provision the target environment
- Run all acceptance tests (using [serverspec](http://serverspec.org/) for instance)


## Usage

If the boxes you want to use exist already in the [Vagrant Cloud](https://atlas.hashicorp.com/boxes/search?vagrantcloud), just run the script `oh-my-box.sh` which gets their names from the script arguments and checks them out.

Otherwise, if the boxes list didn't exist, `oh-my-box` will create them for you based on the specified distros names.

	$ ./oh-my-box.sh [options]

After provisioning and packaging, new Vagrant boxes are generated. E.g:

	<system_username>/debian-jessie-ansible
	<system_username>/centos-7.1-ansible

### Options

    -c, --centos     Prepare a CentOS box
    -d, --debian     Prepare a Debian box
    -o, --opensuse   Prepare an OpenSUSE box
    -s, --sles       Prepare a SLES box
    -u, --ubuntu     Prepare a Ubuntu box
    -x, --clean      Remove basic vagrant box after building the new one
    -h, --help       Show this help message and exit

### Examples

To create a new Debian box, the default Packer template corresponding to the distro name will be used (see `packer/*.json` files):

	(foobar)$ ./oh-my-box.sh --debian

The above commande will create a new Vagrant box `foobar/debian-jessie-ansible` using the default script parameters. To run multiple builds and remove the generated `.boxes` files, after they've been added to save disk space, do as follow:

	(foobar)$ ./oh-my-box.sh -x --ubuntu=baz/ubuntu-14.04 --debian=baz/debian-8.3
	(foobar)$ vagrant box list

		baz/debian-8.3      (virtualbox, 0)
		baz/ubuntu-14.04    (virtualbox, 0)

## Author Information

This tool was created in 2015 by [Ahmed Bessifi](https://www.linkedin.com/in/abessifi/).
