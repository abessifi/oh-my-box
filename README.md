## Description

`Oh-My-Box` is a set of [Packer](https://www.packer.io) templates, [Ansible](http://www.ansible.com) playbooks and Shell scripts which can be used to prepare a bunch of [Vagrant](https://www.vagrantup.com) and [Docker](https://www.docker.com) boxes/images (based on a minimal GNU/Linux images). `Oh-My-Box` uses Packer and Vagrant/Docker tools to:

- Download a minimal image
- Create a virtualbox machine or a docker container
- Provision it using Ansible
- Package the VM to a new Vagrant box (commit the container is the plateform is Docker)
- Add the new created box/image to the Vagrant/Docker local repository

## Requirements

- Virtualbox (tested with 5.0)
- Packer  ( >= v0.8.6 )
- Vagrant ( >= v1.7 )
- Docker  ( >= v1.10 )

## Test case

The created boxes/images can be used, for example, to develop and test Ansible roles on different `GNU/Linux` distributions. Yes, Ansible roles compatibility matters !
For instance, the idea may be to prepare a basic Vagrant/Docker boxes/images with specific `Ansible` and `Ruby` versions which can be used, for example, to run acceptance tests against the Ansible role using [test-kitchen](http://kitchen.ci):

- Create a virtualbox machine or a docker container
- Install the Ansible role to be tested
- Run Ansible to provision the target environment
- Run all acceptance tests (using [serverspec](http://serverspec.org/) for instance)

To activate Ruby installation, set the Ansible variable `install_ruby` to `yes` within the Packer template that corresponds to the GNU/Linux image you want to provision:

    ...
    {
      "type": "ansible-local",
      "playbook_file": "ansible/provision.yml",
      "role_paths": [
        "ansible/roles/init"
      ],
      "extra_arguments": [
        "--extra-vars='{\"install_ruby\":\"yes\"}'"
      ]
    },
    ...

## Usage

If the Vagrant boxes or the Docker images you want to use exist already in the [Vagrant Cloud](https://atlas.hashicorp.com/boxes/search?vagrantcloud) or in the [official Dockerhub registry](https://hub.docker.com/), just run the script `oh-my-box.sh` which gets their names from the script arguments and checks them out.

Otherwise, if the boxes/images list didn't exist, `oh-my-box` will create them for you regarding the specified distros names.

	$ ./oh-my-box.sh [options]

After provisioning and packaging, the new artifacts (boxes or images) are generated. E.g:

	$ vagrant box list

	<username>/debian-jessie-ansible
	<username>/centos-7.1-ansible

	$ docker images --format "table {{.Repository}}\t{{.Tag}}" | awk '$1 ~ /<username>/ { print }'

	REPOSITORY                  		TAG
	<username>/debian-jessie-ansible	latest
	<username>/centos-7.1-ansible		latest

### Options

    -c, --centos     Prepare a CentOS box
    -d, --debian     Prepare a Debian box
    -o, --opensuse   Prepare an OpenSUSE box
    -s, --sles       Prepare a SLES box
    -u, --ubuntu     Prepare a Ubuntu box
    -p, --platform   [vagrant|docker]
                     Prepare a box/image for Vagrant or Docker tools
    -x, --clean      Remove basic vagrant box after building the new one
    -f, --force      Overwrite an existing box
    -h, --help       Show this help message and exit

### Examples

To create a new Debian box, the default Packer template corresponding to the distro name will be used (see `packer/*.json` files):

	(foobar)$ ./oh-my-box.sh --debian

The above commande will create a new Vagrant box `foobar/debian-jessie-ansible` using the default script parameters.

Note that we didn't specify the `--platform` option because by default generated artifact is a Vagrant box. To run multiple builds and remove the generated `.boxes` files, after they've been added to save disk space, do as follow:

	(foobar)$ ./oh-my-box.sh -x --ubuntu=baz/ubuntu-14.04 --debian=baz/debian-8.3
	(foobar)$ vagrant box list

	baz/debian-8.3-ansible      (virtualbox, 0)
	baz/ubuntu-14.04-ansible    (virtualbox, 0)

In the other hand, to build a Docker images for CentOS, you can run the following command:

	(foobar)$ ./oh-my-box.sh --platform=docker --centos=centos-7-ansible:0.1
	(foobar)$ docker images

	REPOSITORY                  TAG
	abessifi/centos-7-ansible   0.1

Note, in the above command if you didn't mention the image tag `0.1`, the tag `latest` will be used as default.

## Author Information

This tool was created in 2015 by [Ahmed Bessifi](https://www.linkedin.com/in/abessifi/).
