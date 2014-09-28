---
date: "2013-08-11"
title: "Infra as a Repo: Separating the Master from the Minion"
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
description: "How to provision a separate Salt master on Digital Ocean."
---

Life can be good. After [my previous success in provisioning a master/minion set-up][my-master], the next logical step was
to introduce a separate master VM. This post explains how I did it. It will be a relatively short post, because it
turned out to be ridiculously easy.


The goal
--------

> Given the current single-server master/minion setup, I want to recreate the same situation with two different
> machines: one Salt master which only functions as a Salt master, and one Salt minion that runs Nginx.

How hard can this be?


A second VM
-----------

[Vagrant][] is built to provision multiple VMs from the same file, so I started by using that feature:

{{% highlight ruby %}}
    # ...
    # SALT is the salt master
    config.vm.define :salt do |node|
        set_network(node, '10.1.14.50', %w(salt.intranet salt))
    end

    # NGINX01 is a web server
    config.vm.define :nginx01 do |node|
        set_network(node, '10.1.14.100', %w(nginx01.intranet nginx01))
    end
{{% /highlight %}}    


The `set_network` function is an expanded version of the `set_host_aliases` function from the [previous post][my-master].
And that's it -- running `vagrant up` will now spin up two virtual machines on my local computer, each with their own
IP address and host names.


Provisioning the master
-----------------------

The Salt machine is meant to be provisioned as a salt master. I already knew how to do that, so this was easily
implemented:

{{% highlight ruby %}}
    # SALT is the salt master
    config.vm.define :salt do |node|
        set_network(node, '10.1.14.50', %w(salt.intranet salt))
        node.vm.synced_folder 'salt/roots/', '/srv/'

        # Salt-master provisioning
        node.vm.provision :salt do |salt|
            salt.bootstrap_script = 'lib/salt-bootstrap/bootstrap-salt.sh'

            salt.install_master = true
            salt.run_highstate = false

            salt.minion_key = 'build/keys/salt.intranet.pem'
            salt.minion_pub = 'build/keys/salt.intranet.pub'

            salt.master_key = 'build/keys/master.pem'
            salt.master_pub = 'build/keys/master.pub'

            salt.seed_master = {
                'salt.intranet' => 'build/keys/salt.intranet.pub',
                'nginx01.intranet' => 'build/keys/nginx01.intranet.pub'
            }
        end

        # And explicitly call the highstate on this one
        node.vm.provision :shell, :inline => 'sleep 60; salt-call state.highstate'
    end
{{% /highlight %}}    

If this looks vaguely familiar, you've obviously read my [previous post][my-master]. If not, go ahead and read it.
The only difference is the addition of a new public/private key-pair for this machine.

This resulted in my master VM being provisioned as a Salt master and Nginx server. Wait. Nginx server? The `top.sls`
file needed a little tweaking as well.

{{% highlight yaml %}}
    base:
        'nginx01.intranet':
            - nginx
{{% /highlight %}}    

Now my VM was provisioned as desired.


Provisioning the minion
------------------------

I told you it was easy:

{{% highlight ruby %}}   
    # NGINX01 is a web server
    config.vm.define :nginx01 do |node|
        set_network(node, '10.1.14.100', %w(nginx01.intranet nginx01))

        # Salt-minion provisioning
        node.vm.provision :salt do |salt|
            salt.bootstrap_script = 'lib/salt-bootstrap/bootstrap-salt.sh'
            salt.run_highstate = true
            salt.minion_key = 'build/keys/nginx01.intranet.pem'
            salt.minion_pub = 'build/keys/nginx01.intranet.pub'
        end
    end
{{% /highlight %}}    

And that's it. Calling `vagrant up` now spins up two VMs: one salt master and one minion that runs as an Nginx server.

Mission Accomplished!


Deploying to Digital Ocean
--------------------------

[I love it when a plan comes together][]. You know the drill: `vagrant up --provider=digital_ocean` and we're good to go.
Reclining in my comfy chair I could see my two machines come up somewhere in a hosting center in New York.

**WARNING**: [Digital Ocean][] VMs cost money. Since I started this series, I've built up a bill of $2.60.
Don't try this if you're really really really broke. In all other cases, they provide good value for money.

_Don't forget: [my infra is a repo](https://github.com/publysher/infra-example-nginx), so go ahead and fork it_


[my-master]: http://blog.publysher.nl/2013/08/infra-as-repo-adding-salt-master.html
[Vagrant]: http://www.vagrantup.com
[I love it when a plan comes together]: http://www.imdb.com/title/tt0084967/quotes?item=qt0378851
[Digital Ocean]: https://www.digitalocean.com/?refcode=8d8ff680bec5
