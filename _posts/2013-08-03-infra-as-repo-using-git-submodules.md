---
layout: post
title: "Using Git Submodules for the salt-vagrant-plugin"
category: "Infra as a Repo"
repo: https://github.com/publysher/infra-example-nginx
---

In my [previous post][], I set up a simple Nginx server using [Vagrant][], [Salt Stack][] and [Digital Ocean][].
However, there was a nagging issue with the [salt-vagrant-plugin][] – I could not get it to install Salt correctly.
In this post, I am revisiting my Salt installation process.


From my previous post:

> Also note that technically, the `vagrant-salt-plugin` is able to install Salt for you as well. However, for some
> reason the plugin has decided that this requires a complete recompile of `python-zmq`, which I am not interested in.
> So I use the official method of installing Salt before I start the plugin.

This Shell provisioning annoyed me mightily, and I went out to investigate. As it turns out, the latest official
release of the `salt-vagrant-plugin` is still using version 1.5.2 of the
[Salt-Boostrap script][salt-bootstrap], while the shell provisioning line uses the [much improved][], [highly praised][]
and [vastly superior][] 1.5.5 release.

Luckily, the `salt-vagrant-plugin` supports custom Salt bootstrap scripts using the aptly named `boostrap_script`
configuration parameter. Unfortunately, we can't point it to e.g.
<https://bootstrap.saltstack.org>, but we must point it to a locally existing
file because..., er..., because [Ruby][].

So, all that remained now was a way to make sure my infra-as-a-repo project always contains a local copy of the
correct version of the bootstrap script. After some mucking about with `Makefile`s, `curl` and `wget`, this
eventually brought me to the long journey of understanding:

Git Submodules
--------------

[Git Submodules][]. As it turned out, this was a surprisingly short journey. Writing this post took more time than
understanding submodules. Git submodules allow you to add a live link to a fixed version of a 3rd part dependency in
another git repository.

{% highlight bash %}

    # Create a directory for your 3rd-party dependencies
    mkdir lib
    # Include the dependency
    git submodule add git@github.com:saltstack/salt-bootstrap.git lib/salt-bootstrap
    # Pin the dependency
    cd lib/salt-bootstrap
    git checkout v1.5.5
{% endhighlight %}

And that's it. I changed my Salt provisioning block in the Vagrant file to this:

{% highlight ruby %}

    config.vm.provision :salt do |salt|
        salt.minion_config = 'salt/standalone-minion'
        salt.bootstrap_script = 'lib/salt-bootstrap/bootstrap-salt.sh'
        salt.run_highstate = true
        salt.verbose = true
    end
{% endhighlight %}

and [voilà!][], I could remove the entire Shell provisioning line.

<div class="mission-accomplished"></div>

So what?
--------

This exercise has brought me three things. First of all, I now understand git submodules. Try it yourself. It's nice.

Second, the separate shell provisioning step really bugged me. I no longer have to roam the streets at 2AM, moaning
about this annoying hack.

And finally, the `salt-vagrant-plugin` is actually quite smart; my happy shell hack reprovisioned Salt Stack at every
run, while the plugin does some nifty detection stuff. This has improved the speed of reprovisioning. Which is nice
when you're doing this in your spare time and need to
reprovision a lot.


Git
---

Of course, the exact commit at the time of writing has been preserved in my repository. Go ahead and
[fork my repo on Github](https://github.com/publysher/infra-example-nginx/tree/v1.1).






[Vagrant]: http://vagrantup.com/
[Digital Ocean]: https://www.digitalocean.com/?refcode=8d8ff680bec5
[Salt Stack]: http://saltstack.com/

[salt-bootstrap]: https://github.com/saltstack/salt-bootstrap
[salt-vagrant-plugin]: https://github.com/saltstack/salty-vagrant

[Git Submodules]: http://git-scm.com/book/en/Git-Tools-Submodules

[previous post]: http://blog.publysher.nl/2013/07/infra-as-repo-using-vagrant-and-salt.html

[Ruby]: http://bit.ly/14QGS6g
[much improved]: https://github.com/saltstack/salt-bootstrap/compare/v1.5.2...v1.5.5
[highly praised]: https://github.com/saltstack/salt-bootstrap/pull/159
[vastly superior]: https://github.com/saltstack/salt-bootstrap/releases/tag/v1.5.5
[voilà!]: http://translate.google.com/#fr/en/Voil%C3%A0!
