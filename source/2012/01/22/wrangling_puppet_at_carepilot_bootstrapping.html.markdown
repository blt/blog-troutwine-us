---
title: Wrangling Servers -- Introduction and Preliminaries
date: 2012/01/20
---

When I was brought on to [CarePilot](https://www.carepilot.com) as Systems
Administrator / Operations Developer we ran on a single(!) box in Amazon's EC2,
no redundancy and nothing in the way of configuration control. I kept nothing of
that box--even moving away from EC2 to Rackspace--and CarePilot runs on kit
built up from scratch, all the way up and down from the DB replication and
backups, to application deployment process to high-level monitoring and
notifications.  It's been my goal at CarePilot to automate, within a reasonable
degree, the maintenance and repair of the machines. Some things I've invented,
others I've picked up and made use of.

While the CarePilot kit was custom crafted, I believe that it's component
pieces--released under commercial-venture friendly open-source licenses--could
be used as the basis of most any tech-startup. This is the first article in a
series that will document my work at CarePilot, introducing some of the
open-source bits of tech I've created and being a bit of a tutorial for those I
merely make use of.

If at the end of these articles you can't piece together a stable base for a new
business let me know: _I wrote something wrong_.

READMORE

## What am I getting myself into?

***

<i>Kindly note, I don't speak for CarePilot. The opinions and preferences I
express here are not necessarily representative of the views of CarePilot. I'm
just a guy talking on his own into the void who happens to work with a great
bunch of folks.</i>

***

As I write this each of the CarePilot machines are shipping their syslogs, other
system logs and data to a central master over a message bus--indirectly in the
case of rsyslog shipping--to a host of message bus savvy listener robots, some
of which provide monitoring reports to me but the majority of which are able to
take action and repair most detected faults, the steps of which are
logged. Faults that can't be repaired become a notification to a human, with a
backup for critical systems being provided by [CloudKick](http://cloudkick.com). System
configuration is managed automatically and version controlled. Application
deployment to staging and production systems are handled in something resembling
Heroku's method: a single git push triggers a process that deploys to all
application servers--or central configuration manager, for _my_ projects--in
real-time, again making use of the message bus.

A CarePilot inspired kit is:

* a central [Puppet](http://puppetlabs.com) master,
* a single [Postgresql](http://postgresql.org) master with one or more hot-standby
  slaves,
* [nginx](http://nginx.org) fronted application servers,
* a [memcached](http://memcached.org) host (with options for expansion),
* a central log collection and analysis server,
* a [Redmine](http://redmine.org) host for issue tracking and planning,
* a central [gitolite](https://github.com/sitaramc/gitolite) server for version
  control and application deployment and
* a [RabbitMQ](http://rabbitmq.org) host (with options for expansion to multiple hosts)
  for transporting event notifications, logs and application messages.

There's a small cadre of tech that I've invented especially for this kit which
we'll get to in due course.

## Bootstrapping Puppet

The absolute heart of this whole setup is Puppet: without it configuration is a
one-off affair, down boxes are not easily replaced and there exists no central
repository for understanding the arrangement of the whole. There are
alternatives--Chef being the most common--but the CarePilot kit uses Puppet for
two reasons:

* I went to [University](http://pdx.edu) and did some projects with a fellow completely
  enamored of it--I believe the good [IT department](cat.pdx.edu) makes heavy
  use of it.
* I lurked for a few days on `#chef` and `#puppet` and found the conversation in
  `#puppet` more civil: it is _vitally_ important that completely naive and
  ignorant questions asked in good faith are met in kind by the community that
  surrounds the tool you intend to use. (I realize that two days does not a
  strong statistical sampling make and that IRC tends to bring out something
  irritable in otherwise kind people.)

The base OS used for the CarePilot kit is Debian Stable, Squeeze at the time of
this writing. With Puppet being written in [ruby](ruby-lang.org) and Debian
support for ruby being somewhat crummy--the Debian Ruby Team, as I understand
it, is understaffed and the ruby community has values somewhat hostile to
Debian's own--there's a hassle here. Namely: do I install puppet from
[rubygems](http://en.wikipedia.org/wiki/Rubygems) or from Debian's packages?
Considerations:

* Puppet in squeeze-backports is version 2.7.6 where current puppet is 2.7.9.
* Debian's puppet required ruby 1.8.7 where mainstream ruby development largely
  targeting the 1.9.
* Puppet's central master has memory-leak issues with ruby 1.8.7.
* We'll be installing system utilities through rubygems anyway later in this
  series.

Rather than suffer with ruby 1.8.7 puppet will be installed as a gem, the
process of which will prime us for quite a bit of work later on.

- - -

<i>Now, before we go further, I suggest you get a virtual-machine setup
going--or rent some servers in a cloud--and follow along. I've used Virtualbox
on my personal machine to spot-check the writing of this series, though I won't
provide instructions on its use. To mimic standard VPS system setup, configure
your systems to have two network interfaces, one for NAT the other for host-only
networking. Make `eth0` the NAT interface. Make sure that `eth1` has a static
address.</i>

- - -

I like to have a template base box which forms the basis of all other box
types. By that I mean most cloud VPS companies allow you to store an 'image', a
pre-configured OS alongside their offered fresh-install OS images. I like to
keep a single base image--carepilot-base, say--which all newly spun-up boxes are
elaborated from, through the use of Puppet. This causes a cyclical dependency
issue which must be resolved by hand: namely, the puppet-master machine will
necessarily require a human to coax it into being. As the puppet-master is not a
production critical piece of infrastructure--its being offline does not stop
customers interacting with the website or other product--I find this
acceptable. If you _do not_ and _do_ come up with an alternative to breaking the
dependency cycle drop me a line!

On the base box we'll install:

* our desired ruby version,
* the puppet gem and
* supervisord to run the puppet client.

Yes, supervisord. Writing init scripts is a bummer--not to mention largely
non-portable--and adding daemonizing code to any system tools you might create
is, likewise, a bummer. In the perfect Unix spirit, why not delegate
daemonization to a special-purpose tool?

### Installing Ruby

It's the ill-named `ruby1.9.1` and `rubygems1.9.1` we want. In actually, these
install, as of this writing, the 1.9._2_ series of interpreter. I'm sure there's
an interesting story there.

    base:~# aptitude install ruby1.9.1 rubygems1.9.1

Some gems we'll need to install have so-called 'native extensions'--C code--so
we're going to need a compiler on our production systems. Possibly a bummer,
depending on your environment. Being certified to handle credit card processing
or to handle some gambling related matters--I'm vague on gambling, sorry--puts a
C compiler or make facility on a production system right out. In general, sure,
yeah, it's important to make your default system as secure as
possible. Consider, though, that:

* the modern Debian system has, in its base install, several Turing-complete
  interpreters able to produce machine code,
* large portions of GCC's support libraries and tools are already installed in
  the base system, an interpreted language could be made to use those tools,
* once a Turing-complete language with FFI ability is already present on a box
  you've installed the equivalent of a C compiler and make system onto a
  production system and
* _real_ system security is about restricting remote access, user access
  controls and segregation.

You _can_ build a box to host your own apt repository for gems and other odds
and ends that need a compiler--keeping those production systems perfectly clear
of this one machine-code production vector--but I'm not convinced that the
effort involved in that is rational given the slight nature of the hazard. It's
unpleasant work and you'll spend a fair bit of time on it, continuously, but it
can be done. I won't do it here and in this series I'll assume that you'll have
installing the following on the base system:

    base:~# aptitude install ruby1.9.1-dev build-essential

To my knowledge there's no automatic alternatives system for ruby. Fun thing
about Debian, though, is that it's:

* always got some tool that will meet your needs and
* isn't as thoroughly documented as you might hope, commensurate to your
  possible needs.

Folks on the various mailing lists are _super_ helpful, however.

    base:~# update-alternatives --install /usr/bin/ruby ruby /usr/bin/ruby1.9.1 400 \
      --slave /usr/share/man/man1/ruby.1.gz ruby.1.gz /usr/share/man/man1/ruby1.9.1.1.gz \
      --slave /usr/bin/irb irb /usr/bin/irb1.9.1 \
      --slave /usr/bin/gem gem /usr/bin/gem1.9.1

You _could_ do something similar for 1.8 as well, but I'm not going to bother.

### Installing Puppet

Compared to getting ruby installed, this is going to be a breeze:

    base:~# gem install facter --version '1.6.4' --no-ri --no-rdoc
    Successfully installed facter-1.6.4
    1 gem installed

    base:~# gem install puppet --version '2.7.9' --no-ri --no-rdoc
    Successfully installed puppet-2.7.9
    1 gem installed

(I hate wasting disk space and don't reference the installed documentation on my
production servers _ever_, so I've skipped building rdocs and the ruby index.)
Note those version numbers; they'll be enshrined in puppet configuration later,
but for now I'd like to make sure, if you're following along, that we're on the
same footing.

One fun _problem_ with Debian and rubygems is that gems' binaries are _not_
installed in the default system `$PATH`. "Wait a second," I can hear my year-ago
self saying to a chilly room and two napping dogs, "they _meant_ to dump gem
binaries into /var/lib?" Yep: so the argument went, /var/lib is state data and
the _state_ for rubygems is all the code plus the executables, never mind the
fact that it's not uncommon to mount /var on it's own partition and set it
noexec in fstab. Anyway, I've heard the Debian team's going to fix this in a
later version of the OS. For now, it's up to us:

* make sure that your `/var` partition is mounted exec (it probably will be) and
* add `[ -d /var/lib/gems/1.9.1/bin/ ] && export PATH="/var/lib/gems/1.9.1/bin/:$PATH"` to the top of /etc/bash.bashrc

### Installing Supervisord

Finally, supervisord:

    base:~# aptitude install supervisor

What we don't want right now is to start the puppet client, either in daemon
form or foreground. It's a right pain dealing with puppet if it mis-creates an
SSL key and on the base box we'll be forced to destroy that key for each new box
derived from the base. It's okay, though: we'll write puppet configuration such
that the first, necessarily manual, run of each puppet client will secure the
box in its intended role.

## Setting up the Puppetd Box

Clone the base image and make a box with hostname `puppet`. This machine will
host the daemonized puppet-master daemon from which all puppet clients will pull
configuration directives. By default, puppet master uses webrick to server
content--a tremendously slow and wasteful web-server fit only for production
purposes. In my experience, even past a few clients, webrick is woefully
under-powered. Happily, it's easy enough to get a production-ready puppet master
installation going.

### First step, Nginx: a proper web-server.

The nginx in Squeeze's default package list is far too old: nearly two years at
this point. Enable the backports repository by creating
`/etc/apt/sources.list.d/backports.list` with the content:

    deb http://backports.debian.org/debian-backports squeeze-backports main

Then:

    # aptitude update && aptitude install -t squeeze-backports nginx

This will ensure that the backports package list is available in your cached apt
index and that nginx is installed from the backports repository. By default
[nginx-full](http://packages.debian.org/squeeze-backports/nginx-full) is
installed, though since we're installing the dummy you can opt to use
nginx-light by installing that package after installing the dummy; the dummy
will remain installed and update nginx-light as needed.

### Second step, Thin: a ruby-rack web-server

If you're not so familiar with ruby-land, 'rack' is a ruby glue layer between
many web-servers and, well, whatever you want to build on top of that
layer. Rails3 is a rack library and puppet, too. What we're going to do is use
the rackup file--'.ru' extension, by convention, and containing instructions
for a rack aware web-server, like thin--shipped with Puppet and have thin create
several puppet master processes, load-balancing with nginx. Supervisord will
manage the parent thin process.

Installing thin is a breeze:

    puppet:~# gem install thin --no-ri --no-rdoc
    Successfully installed eventmachine-0.12.10
    Successfully installed daemons-1.1.6
    Successfully installed thin-1.3.1
    3 gems installed

Again, I've elected to _not_ install documentation. You should notice that there
is now a `thin` executable in your `$PATH`.

The rackup file for puppet is
`/var/lib/gems/1.9.1/gems/puppet-2.7.9/ext/rack/files/config.ru`
