---
date: "2013-07-28"
title: "Infra as a Repo: Using Vagrant and Salt Stack to deploy Nginx on DigitalOcean"
category: "Infra as a Repo"
repo: https://github.com/publysher/infra-example-nginx
tags:
  - devops
  - digital ocean
  - infra as a repo
  - infrastructure
  - salt stack
  - vagrant
  - virtual machine
  - vps
description: "Provisioning an Nginx server on DigitalOcean using Vagrant and SaltStack"
---

I believe that managing your infrastructure can and should be fun. Recently I have been toying around with
[Vagrant](http://vagrantup.com) and [Salt Stack](http://saltstack.com/) to make this a reality. This weekend, 
I managed to combine these tools to automatically provision a new Nginx server on 
[Digital Ocean](https://www.digitalocean.com/?refcode=8d8ff680bec5).


This in itself is nothing new - the interesting part is where I have published the entire script as a Github 
repository without sacrificing any security.

If you're not interested in the story and just want to go and reproduce my infrastructure, go ahead and 
[fork my repo on Github](https://github.com/publysher/infra-example-nginx/tree/v1.0).

The base Vagrantfile
--------------------

I began by using [Vagrant](http://vagrantup.com), an exciting tool that abstracts away all VM hassles into a single 
configuration file. Using a VirtualBox image I created earlier using [Veewee](https://github.com/jedi4ever/veewee), 
the following Vagrantfile allowed me to spin up and destroy a local Debian Wheezy VM.

{{% highlight ruby %}}
    Vagrant.configure("2") do |config|
    
      # Default configuration for Virtualbox
      config.vm.box = 'debian-wheezy-64'
      config.vm.box_url = 'https://www.dropbox.com/s/00ndb5ea4k8hyoy/debian-wheezy-64.box'
    
      # Name the VM
      config.vm.define :nginx01
    
    end
{{% /highlight %}}    

Just by having this simple file, I can now manage a VM with the commands `vagrant up`, 
`vagrant ssh` and `vagrant destroy`.

Salting the image
-----------------

Starting a VM like this is already a sweet experience, but it gets better. The
[salty-vagrant](https://github.com/saltstack/salty-vagrant) plugin allows me to automatically install and configure
software on the VM using the super sweet Salt Stack framework.

Yes, I know, Vagrant supports Puppet and Chef provisioning out of the box, but some time ago I decided that I don't
just want provisioning for my infrastructure. I want a remote execution framework as well. And that's how you end up
with Salt Stack.

Anyway, the following lines in my Vagrantfile were enough to enable Salt Stack:

{{% highlight ruby %}}
    # Mount salt roots, so we can do masterless setup
    config.vm.synced_folder 'salt/roots/', '/srv/'

    # Forward 8080 to nginx
    config.vm.network :forwarded_port, guest: 80, host: 8080

    # Provisioning #1: install salt stack
    config.vm.provision :shell,
        :inline => 'wget -O - http://bootstrap.saltstack.org | sudo sh'

    # Provisioning #2: masterless highstate call
    config.vm.provision :salt do |salt|
        salt.minion_config = 'salt/minion'
        salt.run_highstate = true
        salt.verbose = true
    end
{{% /highlight %}}    

This, and some Salt files of course. They can be found in my
[Github repo](https://github.com/publysher/infra-example-nginx/tree/v1.0) under `salt/roots`. In this case,
the Salt files just install and configure a simple Nginx server, but it's the principle that counts.

Also note that technically, the `vagrant-salt-plugin` is able to install Salt for you as well. However, for some
reason the plugin has decided that this requires a complete recompile of `python-zmq`, which I am not interested in.
So I use the official method of installing Salt before I start the plugin.

And now, after doing a `vagrant up`, the VM is automatically provisioned with a running Nginx server, accessible
through [http://localhost:8080](http://localhost:8080).

Adding Digital Ocean
--------------------

Once again a sweet experience, but hosting my infrastructure on my development machine is not really future-proof.
Which brings me to the next part: deploying the exact same configuration on a real VPS.

Given [the current list of available Vagrant plugins]
(https://github.com/mitchellh/vagrant/wiki/Available-Vagrant-Plugins), and the fact that I don't want to spend too much
on this right now, I decided on using [Digital Ocean](https://www.digitalocean.com/?refcode=8d8ff680bec5). They offer
nice small SSD-backed VPSs for only $5,- a month. And you pay by the hour. Which means that this entire exercise has
cost me $0.05 so far.

The README of the [vagrant-digitalocean](https://github.com/smdahlen/vagrant-digitalocean) plugin is self-explanatory,
but it has one major flaw: it puts your client ID and API key in the main Vagrantfile. Call me old-fashioned, but I
don't like sharing this information on Github.

Luckily, Vagrant has [a complete settings-merging process](http://docs.vagrantup.com/v2/vagrantfile/index.html) in
place, which meant I could simply create the following `~/.vagrant.d/Vagrantfile`:

{{% highlight ruby %}}
    Vagrant.configure("2") do |config|
        config.vm.provider :digital_ocean do |provider, override|
            override.ssh.private_key_path = '~/.ssh/id_dsa'
            override.vm.box_url = 'https://github.com/smdahlen/vagrant-digitalocean/raw/master/box/digital_ocean.box'

            provider.client_id = 'MY-SECRET-ID'
            provider.api_key = 'MY-SUPER-SECRET-API-KEY'
        end
    end
{{% /highlight %}}    

Note the `override.vm.box_url` setting – my beautiful preinstalled Wheezy VM is useless on Digital Ocean, so I just use
their dummy box. Always.

Having set up my private information, I just needed to add the following lines to my main Vagrantfile:

{{% highlight ruby %}}
    # VM-specific digital ocean config
    config.vm.provider :digital_ocean do |provider|
        provider.image = 'Debian 7.0 x64'
        provider.region = 'New York 1'
        provider.size = '512MB'
    end
{{% /highlight %}}    

Deploying the image
-------------------

The proof is in the pudding (apparently), so with great trepidation I did a `vagrant up --provider digital_ocean`.

You should try it yourself – this was really quite exciting. Just a few minutes later, I could access my professionally
provisioned Nginx VPS on [http://192.241.146.220](http://192.241.146.220). Without me ever SSH-ing to the server itself.

Mission Accomplished!

Or was it?

Managing the deployed image
---------------------------

At the moment, Vagrant does not support multiple providers at the same time. So in order to start a local VM
(`vagrant up`), you should do a `vagrant destroy` on the current provider first.

This is not good. The `vagrant destroy` command does exactly what it says, and it destroys your VPS.
Which is sort of missing the point.

In order to switch back to local development, you should remove the `.vagrant/machines/$NAME/digital_ocean/id` file.
This makes Vagrant forget everything it knows about your VPS and `vagrant up` will start a local VM as expected.

And now for the nice part: the `vagrant-digitalocean` plugin actually does not care about this.
The next time you do a `vagrant up --provider digital_ocean`, it will detect your existing VPS by name, and
automatically reinstate the `id`-file.

Reprovisioning the image
------------------------

Provisioning a server is nice, but being able to reprovision a running server is even better. There are three ways to
do this.

The first one is `vagrant provision`, which just runs the provisioning scripts again. This is great for incremental
updates, and it keeps your server online, but it does not guarantee that provisioning works from an initial state as
well.

The second one is `vagrant destroy ; vagrant up --provider digital_ocean`. This will recreate your VPS from the ground
up, ensuring a future-proof provisioning. Unfortunately, Digital Ocean does not guarantee that this will give you the
same IP address. You will also occur a few minutes of downtime.

The final one is `vagrant rebuild`, which does guarantee the same IP address and seems to be functionally equivalent
to the previous method. This too gives you a few minutes of downtime.

One server does not an infrastructure make
------------------------------------------

All of this has of course merely touched the surface of real infrastructure provisioning. Because I don't let Digital
Ocean manage my DNS, I have to manually update my records, the server does not do any monitoring, the current
configuration is not really exciting, and using a masterless Salt minion setup sort of defeats the purpose of using
Salt.

So what.

This exercise has shown me that having your infra as a repo is a viable position, and I am determined to continue down
this path. It might even result in another blog post.



