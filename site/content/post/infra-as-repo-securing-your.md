---
date: "2013-08-31"
title: "Infra as a Repo: Securing your infrastructure with Salt"
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
description: "How to secure your servers with Salt."
---

Provisioning servers on [DigitalOcean][] like a king is one thing, but let's be honest: [default installations don't provide
a lot of security][DandyHack]. So I've spent some time to manage the security on my provisioned boxes. This post (and
probably the next as well) will show you how I used [SaltStack][] to secure my infrastructure.

The goal
--------

> Given the master/minion set-up from the previous posts, I want to have a running firewall which:
>
>   * enables SSH access
>   * enables minion/master communication
>   * enables HTTP(S) access

Quick Fix
---------
The first step was an easy one. In [my previous post][separate-master] I introduced a Makefile to create a public-key
infrastructure; subsequently, the keys were securely distributed using the [salty-vagrant][] plugin.

Unfortunately, I forgot that the directory in which your `Vagrantfile` resides is automatically shared over all machines.
Which means that in practice, I started out with carefully distributing my secret private keys, only to upload them to
all my hosts in the next step.

Luckily, this was easily fixed by the following line in my `Vagrantfile`:

{{% highlight ruby %}}
      config.vm.synced_folder 'shared/', '/vagrant/'
{{% /highlight %}}

Phew.

Adding a Firewall
-----------------
The next step was a bit more complicated: adding firewall rules. Although Salt provides an [iptables module][],
I decided to go for [ufw][]. Partially because I like to be contrarian, but mostly because the UFW guys know more
about firewalls than me.

So, what to do when Salt does not provide a module for your needs? My first attempt looked something like this.

`salt/roots/salt/firewall/base.sls`:

{{% highlight yaml %}}
    ufw:
      pkg:
        - installed
      service:
        - running
        - require:
           - cmd.run: ufw-enable

    # Enable
    ufw-enable:
      cmd.run:
        - name: ufw enable
        - require:
          - pkg: ufw

    # SSH
    ufw-ssh:
      cmd.run:
        - name: ufw allow SSH
        - require:
          - pkg: ufw
        - watch_in:
          - service: ufw
{{% /highlight %}}

`salt/roots/salt/firewall/salt-master.sls`:

{{% highlight yaml %}}
    ufw-salt-master:
      cmd.run:
        - name: ufw allow from $(getent ahosts nginx01.intranet | awk 'NR==1 {print $1}') to any port 4505,4506 proto tcp
        - require:
          - pkg: ufw
        - watch_in:
          - service: ufw
{{% /highlight %}}

`salt/roots/top.sls`:

{{% highlight yaml %}}
    '*':
      - firewall.base
    'salt.intranet':
      - firewall.salt-master
{{% /highlight %}}

And, to be honest, this is not a bad first attempt. I define a base firewall which allows SSH access and enables UFW;
I then proceeded to define a specific rule for the salt master which allows TCP connections to the salt master 0MQ ports
4505 and 4506, and I applied these rules to the correct hosts in `top.sls`.

Still, this set-up has two major problems. First of all, because the commands are [stateless][], they are run
every time the highstate is ensured. Not a huge problem in itself, but not the most beautiful solution either.

Secondly, in order to only allow 0MQ access from my own hosts, I had to resort to a dirty trick; since the IP address
of the various hosts changes per provider, I really need to allow access based on hostname, something that is not
supported by UFW out of the box. Hence the somewhat dubious `$(getent ahosts nginx01.intranet)` fragment in my
`salt-master.sls`.

Creating Salt modules
---------------------
Whenever you have a need that is not covered by the basic Salt modules, the Salt documentation suggests you create
your own modules. And wow, that's easy. (Footnote: my first attempt at provisioning was based on [Puppet][]; customizing
Puppet requires you to do some weird magic in some kind of almost-language called Ruby. It's no fun.)

Salt distinguishes two kind of modules: [execution modules][] (do stuff) and [state modules][] (ensure that stuff is
configured as desired). Let's have a look at my UFW execution module:

`salt/roots/salt/_modules/ufw.py`:

{{% highlight python %}}
    """
    Execution module for UFW.
    """
    def is_enabled():
        cmd = 'ufw status | grep "Status: active"'
        out = __salt__['cmd.run'](cmd)
        return True if out else False


    def set_enabled(enabled):
        cmd = 'ufw --force enable' if enabled else 'ufw disable'
        __salt__['cmd.run'](cmd)


    def add_rule(rule):
        cmd = "ufw " + rule
        out = __salt__['cmd.run'](cmd)
        __salt__['cmd.run']("ufw reload")
        return out
{{% /highlight %}}

Complicated, no? By putting my execution module in the `_modules/` directory, this new execution module is automatically
synced to all minions. (If not, use `salt '*' saltutil.sync_all` to force a new sync). This module is now available
like any salt module: `salt '*' ufw.is_enabled` gives you a nice overview of all minions that have UFW enabled.

Note how I used the `__salt__` dict to defer the actual work to the existing `cmd.run` function. Quite a nice feature.

The state module turned out to be a bit more complicated, but mostly because it has to do a lot of bookkeeping:

`salt/roots/salt/_states/ufw.py`:

{{% highlight python %}}
    # boilerplate & helpers...

    def enabled(name, **kwargs):
        if __salt__['ufw.is_enabled']():
            return _unchanged(name, "UFW is already enabled")

        if __opts__['test']:
            return _test(name, "UFW will be enabled")

        try:
            __salt__['ufw.set_enabled'](True)
        except (CommandExecutionError, CommandNotFoundError) as e:
            return _error(name, e.message)

        return _changed(name, "UFW is enabled", enabled=True)


    def allowed(name, app=None, protocol=None,
                from_addr=None, from_port=None, to_addr=None, to_port=None):

        rule = _as_rule("allow", app=app, protocol=protocol,
                       from_addr=from_addr, from_port=from_port,
                       to_addr=to_addr, to_port=to_port)

        if __opts__['test']:
            return _test(name, "{0}: {1}".format(name, rule))

        try:
            out = __salt__['ufw.add_rule'](rule)
        except (CommandExecutionError, CommandNotFoundError) as e:
            return _error(name, e.message)

        changes = False
        for line in out.split('\n'):
            if line.startswith("Skipping"):
                continue
            if line.startswith("Rule added") or line.startswith("Rules updated"):
                changes = True
                break
            return _error(name, line)

        if changes:
            return _changed(name, "{0} allowed".format(name), rule=rule)
        else:
            return _unchanged(name, "{0} was already allowed".format(name))
{{% /highlight %}}

If you're interested in the helpers and boilerplate, [look here][ufw.py].


The final rules
---------------

Using these brand new modules, the new SLS files looked lot more like proper state files.

`salt/roots/salt/firewall/base.sls`:

{{% highlight yaml %}}
    ufw:
      pkg:
        - installed
      ufw.enabled:
        - require:
          - pkg: ufw


    ufw-ssh:
      ufw.allowed:
        - protocol: tcp
        - to_port: ssh
        - require:
          - pkg: ufw
{{% /highlight %}}

Reprovisioning the VM now behaves as expected – enabling the firewall and adding SSH is executed only once. Furthermore,
the Salt master config has become much more readable:

`salt/roots/salt/firewall/salt-master.sls`:

{{% highlight yaml %}}
    include:
      - firewall.base

    {% for minion in pillar['minions'] %}

    ufw-salt-master-{{ minion }}:
      ufw.allowed:
        - from_addr: {{ minion }}
        - protocol: tcp
        - to_port: "4505,4506"
        - require:
          - pkg: ufw

    {% endfor %}
{{% /highlight %}}

Note how I've sneakily enabled pillar data as well. Deducing the configuration for `firewall/http.sls` is left as
an exercise to the reader ([hint][http.py]).


Conclusion
----------

Managing your firewall with Salt is not that hard; it requires some module magic, but that is very easy to do. Of course,
having a firewall is not enough; stay tuned for the next post where I will add more security measures.

_Don't forget: [my infra is a repo](https://github.com/publysher/infra-example-nginx), so go ahead and fork it_


[DigitalOcean]: https://www.digitalocean.com/?refcode=8d8ff680bec5
[DandyHack]: http://dandydev.net/blog/crashing-servers-and-riding-waves#.UiH0PGTOmwY
[SaltStack]: http://saltstack.com/
[separate-master]: http://blog.publysher.nl/2013/08/infra-as-repo-separating-master-from.html
[salty-vagrant]: https://github.com/saltstack/salty-vagrant
[iptables module]: http://docs.saltstack.com/ref/states/all/salt.states.iptables.html#module-salt.states.iptables
[ufw]: https://help.ubuntu.com/community/UFW
[stateless]: http://docs.saltstack.com/ref/states/all/salt.states.cmd.html
[Puppet]: https://puppetlabs.com/
[execution modules]: http://docs.saltstack.com/ref/#minion-execution-modules
[state modules]: http://docs.saltstack.com/ref/states/writing.html
[ufw.py]: https://github.com/publysher/infra-example-nginx/blob/72837a9cb5cb01e5dab9d3ccfcbf5995a4dcf934/salt/roots/salt/_states/ufw.py
[http.py]: https://github.com/publysher/infra-example-nginx/blob/develop/salt/roots/salt/firewall/http.sls
