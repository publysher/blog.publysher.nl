---
date: "2013-08-09"
title: "Infra as a Repo: Adding a Salt master"
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
description: "How to provision a salt master on Digital Ocean."
---

After I [managed to provision an Nginx server][previous post] using a masterless Salt setup, I felt it was time to
introduce a master. This proved to be a frustrating challenge, but in the end I managed to do it. This post
describes how I did it. It might save you some time.


The goal
--------

> Given the current single-server setup, I want to reach the exact same result using a Salt master. The master
> should run on the Nginx server itself.

How hard can it be?

PKI: The problem
-------------

Salt relies on a [public-key infrastructure][PKI] to let the minions communicate with the master. This means that
every minion has its own public/private key pair, and that the master knows the public key of every minion. Generating
key pairs is not very complex, but distributing keys is.

The private key of the minion

1. Must *only* reside on the minion
2. Must be *securely* transfered to the master
3. Must be *explicitly* accepted by the master
4. Must be accepted *before* the provisioning starts
5. Can *not* reside in my Git repo

The [Salt documentation][Salt-PKI] describes the basic concept of preseeding, but it's severely lacking when you try
to find a solution for all five requirements above. The [Salty Vagrant documentation][Salty Vagrant plugin] provides some
help, but more on that later.

PKI: The short answer
---------------------

I have devised the following solution to the problem of preseeding the Salt master with minion keys:

1. Use `make` and the `openssl` tools to create all public/private key pairs in a separate directory and
   exclude this directory using `.gitignore`
2. Use the Salty Vagrant plugin to distribute the correct keys to the correct minions and to preseed the master with
   the public keys

This violates the first requirement, since the private keys now reside on the computer building the infrastructure and
on the minion that is being built, but for now that is acceptable. The second requirement is probably fulfilled --
I hope and assume that Vagrant syncs its files over SSH. The third and fourth requirement are taken care of by the
Salty Vagrant plugin. The last requirement is fixed by providing a means to generate the keys, instead of storing the
keys themselves in my Git repository.

"But what if you lose the keys?", you might ask. This is actually a funny thing. If I lose the keys, for example by
accidentally typing `make clean`, I just have to regenerate them and rebuild my infrastructure. And since my
infrastructure is *designed* to be rebuilt from scratch over and over again, this is actually not a problem at all.
At least for now. I might revisit this opinion when my infrastructures grows beyond twenty servers.


PKI: The hard part
------------------

Of course, this all fell apart when I tried to implement this. As it happens, the Salty Vagrant documentation refers
to the Git HEAD, not to the official v0.4.0 you ordinarily install. Furthermore, there is a problem with the current
HEAD where preseeding is done incorrectly. There is a [pull request] for that, but it has not been merged yet.

So, save yourself a lot of hairpulling, fork the plugin, apply the pull request, and install the plugin from source.
After this, we're getting close...

{{% highlight ruby %}}
    config.vm.provision :salt do |salt|
        salt.bootstrap_script = 'lib/salt-bootstrap/bootstrap-salt.sh'

        salt.install_master = true
        salt.run_highstate = true

        salt.minion_key = 'build/keys/nginx01.intranet.pem'
        salt.minion_pub = 'build/keys/nginx01.intranet.pub'

        salt.master_key = 'build/keys/master.pem'
        salt.master_pub = 'build/keys/master.pub'

        salt.seed_master = {
            'nginx01.intranet' => 'build/keys/nginx01.intranet.pub'
        }
    end

    config.vm.define :nginx01 do |node|
        node.vm.hostname = 'nginx01.intranet'
        node.vm.network :private_network, ip: '10.1.14.100'
        node.vm.synced_folder 'salt/roots/', '/srv/'
    end
{{% /highlight %}}    

Where is my master?
-------------------

By default, Salt minions look for a host called `salt`. Which of course cannot be found in the setup described above,
because the master is called `nginx01.intranet`. The easy solution would be to provide a custom minion configuration,
but I decided for a more future-proof solution: the [Hostmanager][].

This cute plugin updates the `/etc/hosts`-file on the guests and supports host aliases. It can also be used as a provisioner,
ensuring that all hosts are known to each other before the Salt provisioning starts. And it can also update the
`/etc/hosts`-file on the host machine, which is a nice feature to have.

{{% highlight ruby %}}
    config.hostmanager.enabled = false             # use explicit provisioning
    config.hostmanager.ignore_private_ip = false   # use my :private_network IP

    config.vm.provision :hostmanager               # provision the /etc/hosts file
    config.vm.provision :salt do |...|

    config.vm.define :nginx01 do |node|
        # ...
        node.hostmanager.aliases = %w(salt salt.intranet)   # my aliases
    end
{{% /highlight %}}    

Not so fast...
--------------

More fun ahead. For some idiotic reason, starting the Salt minion takes longer than starting the Salt master. Which
means that during a `vagrant up` provisioning run, the minion seems to be down when the master is trying to call its
highstate.

I tried all kinds of config tweaking to fix this, but in the end I gave up. I wanted to see some results.

{{% highlight ruby %}}
    config.vm.provision :salt do |salt|
        # ...
        salt.run_highstate = false
    end

    config.vm.define :nginx01 do |node|
        # ...
        node.vm.provision :shell, :inline => 'sleep 60; salt-call state.highstate'
    end
{{% /highlight %}}    

Did you notice the subtle `sleep 60` call? This [scientifically determined][trial-error] delay ensures that the
salt minion is up, running and connected when we finally do what we've always wanted to do: running the highstate.

Time for a `vagrant up`.

Mission Accomplished!

Well, almost...

VPS Deployment
-------------

It's fun to have a virtul infrastructure on your own computer, but my original goal has always been to deploy this to
[Digital Ocean] as well. And guess what: the setup described above does not work on a VPS.

Remember this line?

{{% highlight ruby %}}
    config.hostmanager.ignore_private_ip = false    # use my :private_network IP
{{% /highlight %}}    

This line is necessary when working with the virtualbox provider, to ensure that the host files are seed with private
network IPs
instead of the well-known but useless `127.0.0.1` IP. But this setting is global, which means that my VPS will also
search for the `salt` host on `10.1.14.100`. Which is [not going to work][Private Network].

In theory, this can be overridden by using Vagrant's provider override functionality:

{{% highlight ruby %}}
    config.vm.provider :digital_ocean do |provider, override|
        # ...
        override.hostmanager.ignore_private_ip = true
    end
{{% /highlight %}}    

But due to Vagrant's arcane configuration inheritance settings, this nullifies my `node.hostmanager.aliases`
settings.

I tried to solve this by making the value of `ignore_private_ip` depend on Vagrant's `current_provider` setting.
But that does not exist. [And it is not going to exist either.][current-provider]

As it turns out, the recommended approach is to define your own functions. The `Vagrantfile` is just a piece of
Ruby code, so as long as you can program Ruby, you can do everything you want. It's just that I was never interested
in learning Ruby...

{{% highlight ruby %}}
    def set_host_aliases(node, aliases)
        node.hostmanager.aliases = aliases
        node.hostmanager.ignore_private_ip = false

        node.vm.provider :digital_ocean do |provider, override|
            override.hostmanager.aliases = aliases
            override.hostmanager.ignore_private_ip = true
        end
    end

    Vagrant.configure("2") do |config|
        # ...
        config.vm.define :nginx01 do |node|
            # ...
            set_host_aliases(node, %w(salt salt.intranet))
        end
    end
{{% /highlight %}}    

If anyone has a better solution, please let me know! But despite my misgivings about this hack, [it works].

Mission Accomplished! (for real now)

_Don't forget: my infra is a [repo], so go ahead and fork it_


[previous post]: http://blog.publysher.nl/2013/07/infra-as-repo-using-vagrant-and-salt.html
[Salty Vagrant plugin]: https://github.com/saltstack/salty-vagrant
[PKI]: http://en.wikipedia.org/wiki/Public-key_infrastructure
[Salt-PKI]: https://salt.readthedocs.org/en/latest/topics/tutorials/preseed_key.html
[pull request]: https://github.com/saltstack/salty-vagrant/pull/98
[Hostmanager]: https://github.com/smdahlen/vagrant-hostmanager
[trial-error]: http://en.wikipedia.org/wiki/Trial_and_error
[Digital Ocean]: https://www.digitalocean.com/?refcode=8d8ff680bec5
[Private Network]: https://en.wikipedia.org/wiki/Private_network
[current-provider]:https://github.com/mitchellh/vagrant/issues/1867
[it works]: http://nginx01.publysher.nl/
[repo]: https://github.com/publysher/infra-example-nginx
