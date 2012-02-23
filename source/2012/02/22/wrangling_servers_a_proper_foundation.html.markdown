---
title: Wrangling Servers -- A Proper Foundation
date: 2012/02/22
tags: puppet
---

This is the second in a series of articles that walk-through setting up and
maintaining a kit sufficient to run a tech business on. Please make yourself
familiar with the
[first article](../../01/22/wrangling_servers_introduction_and_preliminaries.html), in
which a base image box was setup and a puppet central master box was derived
from the base.

In this article we'll make puppet self-hosting, properly version-control our
puppet configuration and put together a push-style deployment system for every
manner of source code.

As the deployment system is best put in place in the context of a reasonable
puppet setup we'll be chicken-egging it here for a short bit, but, don't worry,
there's much less work in this second piece than the first.

READMORE

# Puppet hosting Puppet

You'll recall that in our last article our two files in /etc/puppet were not
version controlled. Make sure you aren't working on the puppet master and create
a new git repository:

    $ mkdir -p ~/projects/us/troutwine/ops/etcpuppet
    $ cd ~/projects/us/troutwine/ops/etcpuppet

I like to keep my projects namespaced by domain, then by departmental
affiliation--even if I'm the only one working on that domain's IP. The exact
path you supply is probably going to differ. Once in `etcpuppet/`

    $ git init
    Initialized empty Git repository in ~/projects/us/troutwine/ops/etcpuppet/.git/

Create in this directory three files. The first file is `config.ru` and serves
as the instruction set for the thin web-server that powers puppet master.

    $ cat config.ru
    # a config.ru, for use with every rack-compatible webserver.
    # SSL needs to be handled outside this, though.

    # if puppet is not in your RUBYLIB:
    # $:.unshift('/opt/puppet/lib')

    $0 = "master"

    # if you want debugging:
    # ARGV << "--debug"

    ARGV << "--rack"
    require 'puppet/application/master'
    # we're usually running inside a Rack::Builder.new {} block,
    # therefore we need to call run *here*.
    run Puppet::Application[:master].run

Our second file acts as configuration for the puppet master itself.

    $ cat puppet.conf
    [main]
    ssldir=$vardir/ssl

    [master]
    certname=puppet

These files you should recall from the first article.

With no deployment rig in place, we'll begin by muddling through and relay
rsyncing code into place by hand, gradually elaborating on the process up to the
final method. I'm aware of some folks that rsync their configuration directly
into place--from developer machine to production system--but I resist doing that
for a few reasons. Firstly, if /etc/puppet is to be the location of puppet
configuration _and_ user/group puppet is to own this directory the user puppet
must be granted remote login access. The puppet user _should not_ be granted any
manner of login access because the data it owns is used, without suspicion, to
manipulate all the systems in your cluster: any possible breach of the puppet
user account by a remote party would be disastrous. Secondly, to mitigate any
possible breeches of the puppet user, our puppet configuration will be deployed
on a read-only filesystem. Any attacker that _might_ gain access to the puppet
user will be unable to alter data owned by that user: the R/O filesystem will be
mounted by root and unalterable except by the root user. (Other attack vectors
exist; we'll address these later through network design.)

First, rsync the configuration codebase to your puppet box. Recall that I'm
running a virtual box instance on a host-only network; I have the localhost
puppet IP alias as localpuppet in `/etc/hosts` and I've an ssh-key accessible
account on the puppet master box.

    $ rsync -vzr --delete --exclude='.git' -e ssh . localpuppet:etcpuppet
    sending incremental file list
    created directory /home/blt/etcpuppet
    ./
    config.ru
    puppet.conf
    manifests/
    manifests/.gitkeepme

    sent 595 bytes  received 76 bytes  1342.00 bytes/sec
    total size is 479  speedup is 0.71

On the puppet host:

    puppet:~$ sudo rsync -vzr --delete --exclude='.git' etcpuppet/ /etc/puppet/
    sending incremental file list

    sent 599 bytes  received 76 bytes  1350.00 bytes/sec
    total size is 479  speedup is 0.71

Nothing should be synced into `/etc/puppet` as there are no files modified from
the previous article. What we're going to need now are puppet modules to host
puppet itself. This very task is the over-saturated 'Hello World' of puppet, to
the exclusion of other, more interesting, works. Here's what I'm going to do: in
this article we'll plug submodules into the repository we've created and edit a
file or two. Bam: self-hosting puppet. If you're interested in the details or if
you need the tutorial, dive into the source of the submodules introduced. Those
I've written are documented sufficiently to act as a tutorial for the
determined.

Before we begin adding modules we're going to need some boilerplating. The
`manifests/site.pp` is puppet's main method, so to speak: everything included in
this file is all that is available to a puppet agent.

    import 'nodes.pp'

    Exec {
      path => "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
    }

The first line pulls in all of our node definitions. In puppet, a 'node' is a
machine type. Exact demarcation is left up to the user but determined by machine
hostname. We'll use a mixture of 'type' and 'typeNumber', 'puppet'
and 'db0' being exemplars of both methods, respectively. More of that
shortly. The second block sets the shell path for all command invocations. It's
not strictly necessary to set this--puppet can sometimes figure out your path
from the host system--but it _is_ better to be explicit when possible, else all
subsequent Execs will require a `path` line. That's annoying and bug prone. Read
more [here](http://puppetcookbook.com/posts/set-global-exec-path.html).

Our next plate for the boiler is `manifests/nodes.pp`; the import at the top of
`site.pp` is a relative one. You'll find that puppet's inclusion rules are a
little strange. There's a difference, oh yes, between the keywword
['import'](http://docs.puppetlabs.com/guides/language_guide.html#importing-manifests),
which you should almost never use, and
['include'](http://docs.puppetlabs.com/guides/modules.html#module-autoloading),
which you'll use quite a bit. _Please_ read the two documents I've just linked
and make sure you understand them; while the puppet language has some warts they
are, at least, _well documented_ warts. `manifests/nodes.pp` will act as a base
of and import all specific node definitions.

    import 'nodes/*.pp'

    # The base class acts as a repository for configuration common to all the more
    # specific node definintions imported above.
    class base {
      include supervisor, puppet

      # Ensure machine time is always synced to external reference. All system
      # defaults are acceptable.
      package { ntp: ensure => present, }
      # Include for libssl-dev for native rubygems that need SSL (EventMachine).
      package { 'libssl-dev': ensure => present, }
      # Require all machines to have rsync installed for various purposes.
      package { rsync: ensure => present, }

    }

The only node definition we've got at the moment is for the puppet node,
`manifests/nodes/puppet.pp`:

    node 'puppet' {
      include base, puppet::master
    }

That's everything. All that's needed now is to install the submodules referenced
and their dependencies. From the root of your repository:

    $ git submodule add git://github.com/blt/puppet-module-supervisor.git modules/supervisor
    $ git submodule add git://github.com/blt/puppet-apt.git modules/apt
    $ git submodule add git://github.com/blt/puppet-nginx.git modules/nginx
    $ git submodule add git://github.com/blt/puppet-puppet.git modules/puppet

Deploy as above, execute `puppet agent --test` and commit. That's it. I urge you
to have a look through the modules' source; I've worked to comment the modules
well and you really do need to have a handle on everything. Note especially the
nginx module: you'll find many that attempt to use puppet's limited language to
compile vhost definitions into nginx's more, hmm, _vigorous_ configuration
language. I believe this is an exercise in:

* complication
* frustration

neither of which you want when there's something needs fixing, the site's
offline and you're caught in the lurch between the dainty needs of puppet and
unhappy folks. The vhost resource in the nginx module will take care of the
hidden details of the nginx module but require that you pass in a template as
content for the vhost. That way you get the full acrobatics of nginx without any
of the heartache of mimicking that in puppet.

Now that puppet is self-hosting, you should commit all of this to version
control, finally.

    $ git add * && git commit -m "Initial commit"

Congratulations: your puppet configuration is now checked into version
control. Add any remote repositories you might care to and push your code up and
away to Github or some other reasonably disaster-proof repository host. I tend
to use the remote branch name 'backup' for this need and reserve 'production'
for the fork that will be deployed to live puppet master.

## Deployment

Using rsync is passable when we're developing but it's not going to cut it
long-term. (You can get pretty elaborate with rsync, though. I'm fond of
daisy-chaining rsyncs across machines, spinning up as needed with inotifywait.)
The deployment strategy we're going to build requires:

* A central git repository for 'blessed' production / staging / testing repos.
* A message bus.
* A message to command the invocation server.

The two options that I'd like to make you aware of for this last point are
[mcollective](http://puppetlabs.com/mcollective/introduction/) and my
[traut](https://github.com/blt/traut). Mcollective has company backing, scales
way up and is a pseudo-interactive shell to all nodes in the collective. You can
do _very_ cool stuff with mcollective. Alternatively, traut is a small
open-source project, has no company backing and is really just a cron-like for
messaging. You write your commands in any language that will take stdin, unlike
mcollective which is a ruby only party. Traut is also _stupid_ simple to get
running and keep that way.

If you know cron, you know traut. Mcollective is _much_ larger project that you
should _probably_ transition to when your business takes off, your ops team is
funded or you have a bit of time on your hands. Once you have more than twenty
computers in your cluster--or if you find yourself ssh'ing into your machines
constantly--put some time into learning mcollective.

Till then, deployment works like this:

* A user pushes code into a blessed code repository, the post-receive hook is
  invoked and sends a specially formed message through the bus.
* The post-receive hook's message is caught by a traut script which builds a
  deployable slug, placing it in a remotely accessible directory on the
  filesystem. This slug building script then fires off a notification message
  through the bus.
* Traut clients, pre-configured to invoke a command for the notification
  message, download the new slug and deploy it.

The slug building hook that I'll introduce here is primitive: it simple-mindedly
strips out git metadata and bundles all the source-code into a single squashfs
file. This is great for puppet configurations, less so for complex
applications. Adding heuristic running of a project's Makefile, Rakefile, ant or
another script is not at all difficult; I just didn't get around to it. If this
becomes a problem for you and I've not fixed it up between writing this and your
involvement,
[take out an issue](https://github.com/blt/puppet-slugbuild/issues)?

### A central git repository

Go ahead and fire up another machine, call it 'git'. This machine will host the
'blessed' repositories using [gitolite](https://github.com/sitaramc/gitolite) to
provide access control. A word of warning, the manner in which gitolite is
configured makes it difficult to fully automate: doing commits into gitolites'
`gitolite-admin` repository is pretty slick, but I'm not clever enough to use
puppet with that. (If you are, email me!)

Once the machine is ready, the first thing you're going to need to do is get the
git box's puppet agent keyed into puppet master. To this point I've ignored
networking. Perhaps you're in an environment with DNS pre-baked. If not, I'll
cover setting up DNS in a later article. For now, and this is not a _bad_
solution, consider setting IPs statically in /etc/hosts. Until I actually write
the DNS article, that's what I'll be doing. Be sure that the hostname `puppet`
points to your puppet master box.

    git:~# puppet agent --test  --waitforcert 30 --server puppet

Now, switch back to the puppet master

    puppet:~# puppet cert list
      git.troutwine.us (8E:A8:C0:03:9D:53:1A:CA:FC:25:16:82:88:F8:3F:B4)

The FQDN will be different for you (most likely) but you should see the git box
waiting to have its certificate signed.

    puppet:~# puppet cert sign git.troutwine.us
    notice: Signed certificate request for git.troutwine.us
    notice: Removing file Puppet::SSL::CertificateRequest git.troutwine.us at '/var/lib/puppet/ssl/ca/requests/git.troutwine.us.pem'

Substituting, of course, for your domain.

 We're going to use a
[preseed](http://d-i.alioth.debian.org/manual/en.i386/apb.html) to automate the
package configuration of gitolite for two reasons:

* the default user in the package is 'gitolite' rather than 'git' (I _hate_ that)
  and
* an admin ssh key must be supplied for the package to finish its installation.

The second point is the most pressing but the first is important too: there is
no shame in being meticulous if such behaviors simplify setup or remove
surprises for your users.

From the root of your puppet configuration, install the gitolite module:

    $ git submodule add git://github.com/blt/puppet-gitolite.git modules/gitolite

The node definition for 'git' is very short. In `manifests/nodes/git.pp`:

    node 'git.troutwine.us' {
      include base

      # Install the gitolite daemon and provide the admin key.
      class { 'gitolite':
        gituser => 'git',
        admin_key => 'ssh-rsa AAAAB3NSKIPAFEW',
        path => '/var/lib/git',
      }
    }

The installation of the gitolite daemons and user is interfaced through a class:
you may not, therefore, install multiple copies of gitolite on a single
system. This is counter to the full capability of gitolite--multiple installed
copies, one per user--but I find it much less error-prone to divide gitolite
installations per domain.

### Installing traut and the RabbitMQ message bus

Before we fuss about with post-receive hooks we'll get the remaining kit for
deployment humming. Spin up a new machine to host the message bus, call it
'mq0'. Introduce the node mq0 to puppet and add the RabbitMQ configuration
module to your root configuration:

    $ git submodule add git://github.com/blt/puppet-rabbitmq.git modules/rabbitmq

Unless you have a certificate authority in place--which I'm assuming you don't,
at this point--add my openssl module as well:

    $ git submodule add git://github.com/blt/puppet-openssl.git modules/openssl

A better name for the openssl module might be 'poor-mans-ca', but I thought that
a bit long. The module, inspired by
[ssh-auth](http://projects.reductivelabs.com/projects/puppet/wiki/Module_Ssh_Auth_Patterns),
will build, sign and distribute certificates sufficient to run an encrypted
internal network. It is _not_ a secure certificate authority for the wider
internet--don't issue these things to hosts that have to rove or, God forbid, to
a client. However, so long as you're able to keep the machine hosting the
private keys secure--and we're going to install the keys to the puppet master,
so you should--this will be just dandy. To be clear: __if an attacker gets
access to the filesystem of your puppet master, they will be able to decrypt any
communication over channels signed with the keys generated by this module.__

Why go to all the trouble of generating certificates for all clients and
servers? Hopefully the benefit of running communications to a server daemon over
an encrypted channel is obvious to you, but generating keys for a client, as
well? Control, simply. The message bus will be used to cause sensitive tasks to
kick off; mere encrypted channels do not deny unknown parties from establishing
connections and pumping messages through. The RabbitMQ setup advocated here
will:

* require clients to supply a known username and password and
* supply a certificate co-signed with the server's own.

In `manifests/nodes.pp` add the following:

    # Until there's a pressing need to construct a more traditional CA for
    # internal services, the puppet-openssl module can construct a primitive
    # one. The master will be placed on puppet, making that box _extremely_
    # sensitive to tampering. It was, of course, already _extremely_ sensitive to
    # tampering.
    if $hostname == 'puppet' {
      class { 'openssl::certmaster':
        ca_name => 'rabbitmq',
        ensure => present,
      }
    }
    Openssl::Server {
      ca_name => 'rabbitmq',
    }
    openssl::server {
      'mq0' : ensure => present;
    }
    Openssl::Client {
      ca_name => 'rabbitmq',
    }
    openssl::client {
      'puppet': ensure => present;
      'git'   : ensure => present;
      'mq0'   : ensure => present;
    }

All three nodes will be issued client certificates for RabbitMQ, placed in
`/etc/rabbitmq/ssl/client`. The location is configurable, more nodes can be
added as can more services.

Installing the RabbitMQ daemon is a relatively simple matter. Create an mq node
definition, `manifests/nodes/mq.pp`:

    node /^mq\d+/ {
      include base, rabbitmq
    }

The installation of the traut daemon should be unsurprising

    $ git submodule add git://github.com/blt/puppet-traut.git modules/traut

except that, instead of creating a new node, we'll add 'include traut' to the
base node class in `manifests/nodes.pp`. The traut module comes with a few optional
goodies, one of which is [hare](https://github.com/blt/hare). In
`manifests/nodes.pp` add:

    # The traut daemon which allows cron-like action in response to AMQP
    # messages. Here we install cron on all systems and enable a 'puppet agent
    # --test' event.
    $traut_vhost = '/traut'
    $traut_user  = 'traut'
    $traut_pass  = '264l8uSlCeZSGZiCQHns'
    $traut_key   = '/etc/rabbitmq/ssl/client/key.pem'
    $traut_chain = '/etc/rabbitmq/ssl/client/cert.pem'

    class { 'traut':
      ensure => present,
      vhost => $traut_vhost,
      host => 'mq0',
      username => $traut_user,
      password => $traut_pass,
      exchange => 'traut',
      debugging => true,
      version => '1.0.1',
      private_key => $traut_key,
      cert_chain => $traut_chain,
      require => File[$traut_key, $traut_chain],
      subscribe => File[$traut_key, $traut_chain],
    }
    include traut::hare

This is a bit long and I urge you to read the documentation provided with the
puppet-traut module. Suffice it to say that all nodes will have traut installed,
traut will connect to the RabbitMQ daemon on `mq0` over SSL (with a client
certificate) and using the supplied password and username. __Be sure to change,
at least, the value of `$traut_pass` in your setup.__

To enable specially coded messages on every push for the 'puppet repository, in
`manifests/nodes/git.pp` add:

    # Ensure that on pushes into the 'puppet' git repository traut notifications
    # are sent out via the post-hook.
    gitolite::resource::posthook { 'puppet':
      mqpass => "${base::gitolite_posthook_password}",
    }

With that in mind, go ahead and _setup_ the 'puppet' repository by cloning
gitolite-admin and adding the appropriate entries. Be sure to commit and push
back your changes.

That done, in `manifests/nodes/mq.pp` add:

    # The traut vhost RabbitMQ user and /traut vhost are are used by the traut
    # system daemon. /traut should be shared among multiple RabbitMQ users, where
    # the traut user _must_ be exclusive to the similarly named daemon.
    rabbitmq::resource::vhost { "${base::traut_vhost}":
      ensure => present,
    }
    rabbitmq::resource::user { "${base::traut_user}":
      require => Rabbitmq::Resource::Vhost["${base::traut_vhost}"],
      password => "${base::traut_pass}",
      ensure => present,
    }
    rabbitmq::resource::user::permissions { "${base::traut_user}":
      require => Rabbitmq::Resource::User["${base::traut_user}"],
      vhost => "${base::traut_vhost}",
      ensure => present,
    }

This creates the RabbitMQ traut user with the password and the traut vhost, all
specified in `nodes.pp`.

Redeploy and re-run puppet agent on all hosts. You should see traut installed to
each system, as well as RabbitMQ on mq0. Depending on the order that `puppet
agent` fires on your nodes you may need to run it several times so that ssl keys
distribute properly. See the puppet-openssl documentation for more details.

Before moving on, ensure that all nodes have 'mq0' resolves in DNS or are set in
/etc/hosts; you can manage _that_ with puppet if you'd like. Add the following
to `manifests/nodes.pp`:

    # Without an internal DNS system, nor a pressing need for one until the
    # cluster grows substantially, set hostnames manually through /etc/hosts.
    host {
      'puppet.troutwine.us':
        ensure => present,
        ip => '192.168.56.11',
        host_aliases => 'puppet';
      'git.troutwine.us':
        ensure => present,
        ip => '192.168.56.12',
        host_aliases => 'git';
      'mq0.troutwine.us':
        ensure => present,
        ip => '192.168.56.13',
        host_aliases => 'mq0';
    }

substituting, of course, for your setup's IP addresses and domain name.

### At last: deploying

The final piece to this article are a series of shell-scripts that turn traut
events into deployable code. I've rolled this into a puppet module as well:

    $ git submodule add git://github.com/blt/puppet-slugbuild.git modules/slugbuild

In `manifests/git.pp` add the following:

    class { 'slugbuild':
      ensure => present,
      githosts => 'git.troutwine.us,github.com',
      gitcentral => 'git.troutwine.us',
      mqpass => "${base::gitolite_posthook_password}",
    }
    slugbuild::resource::traut { 'puppet':
      ensure => present,
    }
    slugbuild::resource::authorized_key {
      'puppet root':
        ensure => present,
        key => 'AAAABSKIPAFEW';
    }

the exact happenings are documented in the module. Hopefully you noticed that
`slugbuild::resource::authorized_key` requires you specify an ssh public
key. This key, specifically, is for the root puppet master user to the
'slugbuild' user on the git node. Using this access, the puppet node's root will
sync slugs. In `manifests/nodes/puppet.pp` add:

    # This key is generated so that the root user can pull source slugs from the
    # slugbuilder. Note, however, that the public key is _not_ automatically
    # placed into the slugbuilder's authorized_keys and must be done so manually
    # with slugbuild::resource::authorized_key on the slugbuild node.
    user { 'root':
      ensure => present,
    }
    ssh::resource::key { 'id_rsa':
      root => '/root/.ssh/',
      ensure => present,
      user => 'root',
    }
    ssh::resource::known_hosts { 'root':
      root => '/root/.ssh/',
      hosts => 'git.troutwine.us',
      user => 'root',
    }

    # The slugbuild sync will, post-build, sync all available slugs to the local
    # machine using the credentials generated above.
    class { 'slugbuild::slugclient':
      ensure => present,
      mqpass => "${base::gitolite_posthook_password}",
      slughost => 'git.troutwine.us',
    }
    slugbuild::resource::sync { 'puppet-sync':
      project => 'puppet',
      ensure => present,
    }

    # Ensure that newly available puppet configuration slugs are mounted and
    # linked as /etc/puppet
    class { 'puppet::resource::redeploy':
      ensure => present,
    }

The first half constructs ssh keys for the root user of the puppet master, the
latter half sets up puppet master as a slugbuild client to
`git.troutwine.us`. Be sure to use the contents of `/root/.ssh/id_rsa.pub` as
data to the key parameter of `slubuild::resource::authorized_key`.

Redeploy your puppet configuration through the rsync daisy chains. Run
puppet-agent on all your machines. Commit all of your changes. With everything
in place remove `/etc/puppet` on the puppet master and push to the gitolite
repository you've created. After a few moments, you _should_ find that slugbuild
on the git node has created slugs, these have been transferred over to the
puppet node and the latest has been mounted as `/etc/puppet`. Subsequent commits
will likewise be handled, with the mount point being swapped atomically.

# Where to next?

<div class="poetry">
There ain't nothing more to write about, and I am rotten
glad of it, because if I'd a knowed what a trouble it was to make a book I
wouldn't a tackled it, and ain't a-going to no more.
<br/>
<small>Huckleberry Finn</small>
</div>

I figured that this article would take a week, tops, to write. Instead, it took
nearly a month! See my [Github](https://github.com/blt) for all the `puppet-*`
activity. Find the repository I've created using the above instructions [here](https://github.com/blt/troutwineus-puppet-example).

That said, there's still plenty to do but I feel remiss in not taking more time
to document the modules already used. You _should_, at this point, have a pretty
decent base on which to build. I'll keep fleshing this out, but go ahead and
email me or get in touch with the
[Puppet Users](http://groups.google.com/group/puppet-users) mailing list if
you're eager to get moving. I'm also available for hire, as it happens.

- - -

These last few articles have been similar in scope to the puppet books I'm aware
of on the market--a fact which didn't occur to me at the outset. Turnbull's
books were an excellent reference when I started out:

* [Pulling Strings with Puppet](http://www.amazon.com/gp/product/1590599780?ie=UTF8&ref_=sr_1_2&qid=1329859043&sr=8-2)
* [Pro Puppet](http://www.amazon.com/Pro-Puppet-James-Turnbull/dp/1430230576/ref=sr_1_1?ie=UTF8&qid=1329859043&sr=8-1)

The Puppet project also has very decent documentation. I keep the following
bookmarked:

* [Puppet Labs Documentation -- Index](http://docs.puppetlabs.com/index.html)
* [Docs: Type Reference](http://docs.puppetlabs.com/references/stable/type.html)
* [Docs: Configuring Puppet](http://docs.puppetlabs.com/guides/configuring.html)
* [Docs: Function Reference](http://docs.puppetlabs.com/references/stable/function.html)
* [Docs: Metaparameter Reference](http://docs.puppetlabs.com/references/stable/metaparameter.html)
* [Docs: Language Guide](http://docs.puppetlabs.com/guides/language_guide.html)

Next time we'll start digging back through some modules and examining them in
detail, examining several simple modules in a bundle and, later, a single module
per article. The [puppet-openssl](https://github.com/blt/puppet-openssl) will
certainly be a long article just to itself.
