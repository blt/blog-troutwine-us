---
title: Wrangling Servers -- Introduction and Preliminaries
date: 2012/01/20
tags: puppet
---

When I was brought on as [CarePilot](https://www.carepilot.com) as Systems
Administrator / Operations Developer we ran on a single(!) box in Amazon's EC2,
no redundancy and nothing in the way of configuration control. I kept nothing of
that box--even moving away from EC2 to Rackspace. CarePilot runs on kit
built up from scratch, all the way up and down from the DB replication and
backups, to the application deployment process to high-level monitoring and
notifications.  It was my goal at CarePilot to automate, within a reasonable
degree, the maintenance and repair of the machines. Some things I've invented,
others I've picked up and made use of.

While the CarePilot kit was custom crafted, I believe that it's component
pieces--released under commercial-venture friendly open-source licenses--could
be used as a base for most any tech-startup. This is the first article in a
series that will document the kit I've produced, introducing some of the
open-source bits of tech I've created and server as a bit of a tutorial for
those I merely make use of.

If at the end of these articles you can't piece together a stable base for a new
business let me know: _I wrote something wrong_.

READMORE

## What are you getting yourself into?

***

<i>Kindly note, I don't speak for CarePilot. The opinions and preferences I
express here are not necessarily representative of the views of CarePilot. I'm
just a guy talking on his own.</i>

***

Imagine that you're employee #3 of a startup and are getting pulled into more
Ops work as the load on your few EC2 boxes gets high: all day you fiddle with
this and that, then _bam_ one of the servers goes offline and you have to piece
a new image up by hand. The site is offline, meanwhile, and employees #1 and #2
can't help but give you the stink-eye. Or, imagine that you're the kind of
person to release small profit generating web-apps every few months and one has
finally taken off. Success! But the load on the $36 Heroku instance you're
running on is too high and the site's suffering. You can crank up the Heroku
toggles to meet the load, but you're going to lose profitability that way. Time
to move to virtual hosting, keeping in mind that you _have_ to keep your Ops
work to a minimum.

What do you do, in either case? Use Puppet. Puppet is a relatively easy to use
state management tool--that makes an excellent sideline into acting as a
configuration tool--is well documented and backed by a company of [nice
folks](http://puppetlabs.com/) and [nice
users](http://groups.google.com/group/puppet-users). Puppet is _not_ an easy
thing to bootstrap, however. This article, and the one that follows it, will
walk you through getting a production-ready puppet setup bootstrapped, along
with a few extra goodies that I _think_ you'll find very helpful.

Should take a few hours. In this article I'll walk you through:

* setting up a base box image,
* version controlling puppet configuration right off and
* bootstrapping a central puppet master from a base box.

The lack of configuration management makes this a much larger task than it would
be _with_ configuration management: take heart, this is the _hard_ part.

## Bootstrapping Puppet

The absolute heart of a managed server cluster, as conceived here, is Puppet:
without it configuration is a one-off affair, down boxes are not easily replaced
and there exists no central repository for understanding the arrangement of the
whole system. There are alternatives--Chef being the most common--but the kit
I'm going to outline here uses Puppet for two reasons:

* I went to [University](http://pdx.edu) and did some projects with a fellow
  completely enamored of it--I believe the good [IT
  department](http://cat.pdx.edu) makes heavy use of it.
* I lurked in the Chef and Puppet communities for a time and found the
  conversation in Puppet's more helpful to the almost-hopelessly
  ignorant. Posting a puppet related question to
  [ServerFault](http://serverfault.com/questions/tagged/puppet) and having a
  detailed answer within the half-hour is a fine thing.

The base OS used for this kit is Debian Squeeze. With Puppet being written in
[ruby](http://ruby-lang.org) and Debian support for ruby being somewhat
crummy--the Debian Ruby Team, as I understand it, is understaffed and the ruby
community has values somewhat hostile to Debian's own--there's a hassle
here. Namely: do I install puppet from
[rubygems](http://en.wikipedia.org/wiki/Rubygems) or from Debian's packages?
Considerations:

* Debian's puppet requires ruby 1.8.7 where mainstream ruby development largely
  targets 1.9.
* Puppet's central master has had memory-leak issues with ruby 1.8.7.
* We'll be installing system utilities through rubygems later in this
  series.

Rather than suffer with ruby 1.8.7 puppet will be installed as a gem, the
process of which will prime us for quite a bit of work later on.

- - -

<i>Before we go further, I suggest you get a virtual-machine setup
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

It's the ill-named `ruby1.9.1` and `rubygems1.9.1` we want. In actuality, these
install, as of this writing, the _1.9.2_ series of interpreter. I'm sure there's
an interesting story there.

    base:~# aptitude install ruby1.9.1 rubygems1.9.1

Some gems we'll need to install have so-called 'native extensions'--C code--so
we're going to need a compiler on our production systems. Possibly a bummer,
depending on your environment. Being certified to handle credit card processing
or to handle some gambling related matters--I'm vague on gambling, sorry--puts a
C compiler or make facility on a production system right out. In general, sure,
it's important to make your default system as secure as possible. Consider,
though, that:

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
installed the following on the base system:

    base:~# aptitude install ruby1.9.1-dev build-essential libssl-dev

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

You _could_ do something similar for 1.8 as well, but I'm not going to
bother. You will need to have git and openssl present on all of your systems:

    base:~# aptitude install git openssl

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

There must be a `puppet` group and user available on the box:

    base:~# adduser --group --system --home /etc/puppet --disabled-password puppet

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
configuration directives. By default, puppet master uses webrick to serve
content--a tremendously slow and wasteful web-server fit only for development
purposes. In my experience, even past a few clients, webrick is woefully
under-powered. Happily, it's easy enough to get a production-ready puppet master
installation going.

### First step, Nginx: a proper web-server.

The nginx in Squeeze's default package list is far too old: just over two years
at this point. Enable the backports repository by creating
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
the rackup file--'.ru' extension, by convention, which contains instructions for
a rack aware web-server, like thin--shipped with Puppet. Then we'll create
several thin / puppet master processes, load-balancing over them with nginx and
managed by supervisord.

Installing thin is a breeze:

    puppet:~# gem install thin --no-ri --no-rdoc
    Successfully installed eventmachine-0.12.10
    Successfully installed daemons-1.1.6
    Successfully installed thin-1.3.1
    3 gems installed

Again, I've elected to _not_ install documentation. You should notice that there
is now a `thin` executable in your `$PATH`, but not in a really pleasing place
to type out. The Debian alternatives system again:

    puppet:~# update-alternatives --install /usr/bin/thin thin /var/lib/gems/1.9.1/bin/thin 400

The rackup file for puppet is
`/var/lib/gems/1.9.1/gems/puppet-2.7.9/ext/rack/files/config.ru` and should be
copied into /etc/puppet:

    puppet:~# cp /var/lib/gems/1.9.1/gems/puppet-2.7.9/ext/rack/files/config.ru /etc/puppet/

In `/etc/supervisor/conf.d/puppetmaster.conf` create a file with this content:

    [program:puppetmaster]
    numprocs=3
    command=/usr/bin/thin start -e development --socket /var/run/puppet/master.%(process_num)02d.sock --user puppet --group puppet --chdir /etc/puppet -R /etc/puppet/config.ru
    process_name=%(program_name)s_%(process_num)02d
    startsecs=5

Thin is run in development mode so that it will not daemonize. The supervisord
option `numprocs` is used to cluster instances, at small cost of RAM and
initial complexity. Be sure _not_ to spin these processes up as we do not yet
have puppet configuration in place.

### Third step, Nginx+Thin: servicing puppet clients

By default, puppet master stores its SSL certificates in `/etc/puppet`. This is
less than ideal: we're going to version the manifests and configuration in this
directory with git--and we don't want to check-in private certificates, just in
case. Not to mention that there _are_ better places on disk for SSL
certs. Create `/etc/puppet/puppet.conf` like so:

    [main]
    ssldir=$vardir/ssl

    [master]
    certname=puppet

Hopefully the
['ssldir'](http://docs.puppetlabs.com/references/stable/configuration.html#ssldir)
is sensible enough. That last line `certname=puppet` changes the default name of
the puppet master pem from the FQDN to, well, just 'puppet'. The FQDN pem makes
it difficult to have a generic and relatively simple bootstrapping process
because we'd be forced to tweaking our actions slightly for every new domain;
boot-strapping should be as quick and as simple as possible. Else, you'll
probably forget a step and spend forty-five frustrating minutes wondering why
nothing works when I've been so _blase_ in declaring the straight-forward nature
of this work.

- - -

<i>You might wonder why there have been two files placed in /etc/puppet but no
versioning having been applied. The deployment process will assume that your
puppet configuration is held in a git repository. I'll walk through this in the
next article, introducing an interim deployment strategy as we work to get the
kit online sufficient to support the final process.</i>

<i>There won't be any more edits to files in /etc/puppet for the remainder of
this article.</i>

- - -

You can execute the puppetmasterd script in non-daemon, debug mode and determine
if your installation has gone well. You should see a 'Finishing transaction'
message as the final output of this command:

    puppet:~# puppetmasterd --no-daemonize --debug

Send the process SIGINT to return your terminal; you won't hurt anything. For
restricted, privileged writing of pidfiles, domain sockets and logs:

    puppet:~# mkdir /var/run/puppet && chown puppet:puppet /var/run/puppet
    puppet:~# mkdir /var/log/puppet && chown puppet:puppet /var/log/puppet

With thin running all that remains is getting nginx to front for it. Edit
`/etc/nginx/sites-enabled/default` to read

<pre>
server {
  # I'm assuming that 'puppet' resolves to a private IP. Don't run Puppet on the public internet!
  listen puppet:8140;

  ssl on;
  ssl_certificate /var/lib/puppet/ssl/certs/puppet.pem;
  ssl_certificate_key /var/lib/puppet/ssl/private_keys/puppet.pem;
  ssl_ciphers ALL:-ADH:+HIGH:+MEDIUM:-LOW:-SSLv2:-EXP;
  ssl_client_certificate  /var/lib/puppet/ssl/ca/ca_crt.pem;
  ssl_verify_client optional;

  # Force all filetypes to be sent raw. (Ouch!)
  types { }
  default_type application/x-raw;

  # serving static files from mount point
  location /production/file_content/files/ {
    ## problem here is that puppet factor doesn't give compact CIDR for network
    # allow   192.168.56.0/16;
    # deny    all;

    alias /etc/puppet/files/;
  }

  # serving static files from modules mounts
  location ~ /production/file_content/[^/]+/files/ {
    ## see above
    # allow   192.168.56.0/16;
    # deny    all;

    root /etc/puppet/modules;

    # rewrite /production/file_content/module/files/file.txt
    # to /module/file.text
    rewrite ^/production/file_content/([^/]+)/files/(.+)$  $1/$2 break;
  }

  location / {
    proxy_pass http://puppet-production;
    proxy_redirect   off;
    proxy_set_header Host             $host;
    proxy_set_header X-Real-IP        $remote_addr;
    proxy_set_header X-Forwarded-For  $proxy_add_x_forwarded_for;
    proxy_set_header X-Client-Verify  $ssl_client_verify;
    proxy_set_header X-Client-Verify  SUCCESS;
    proxy_set_header X-Client-DN      $ssl_client_s_dn;
    proxy_set_header X-SSL-Subject    $ssl_client_s_dn;
    proxy_set_header X-SSL-Issuer     $ssl_client_i_dn;
  }
}
</pre>

and `/etc/nginx/conf.d/puppet-production-upstream.conf` to read:

    upstream puppet-production {
      server unix:/var/run/puppet/master.00.sock;
      server unix:/var/run/puppet/master.01.sock;
      server unix:/var/run/puppet/master.02.sock;
    }

We're causing the local nginx server to respond to hostname 'puppet' requests
by passing them on to the puppet master backends responding over the domain sockets we
defined in the last section. Nginx handles the SSL mongering for puppet and sets proxy values, as defined in the 'default' vhost.

Note that, thanks to our use of `certname` in puppet configuration we can refer
to the generic 'puppet.pem' in the ssl configuration. I won't elaborate on the
hows and the whys--mostly because they're uninteresting--but if you'd like to
read up on the Nginx bits do so [here](http://wiki.nginx.org/Modules) and search
[this
document](http://docs.puppetlabs.com/references/stable/configuration.html). If
I've skipped over something unrealistically fast drop me a line. You'll find my
email address in the footer of this page. Search for 'Contact me.'

You should now be able to start the puppet master. First, restart nginx:

    puppet:~# /etc/init.d/nginx restart

Now cause supervisord to re-read its configuration and start up the thin process
hosting puppet master.

    puppet:~# supervisorctl reread
    puppet:~# supervisorctl update
    puppet:~# supervisorctl start puppetmaster:*

Before you attempt to run the puppet agent, be aware that puppet master running
on ruby 1.9.2 has an interesting
[issue](http://projects.puppetlabs.com/issues/9084), which, since we're using a
base system, is going to be easy enough to correct. Do all of the following,
taking careful note of the _systems_ the commands are run on.

    puppet:~# ln -s /var/lib/puppet/ssl/certs/ca.pem $(openssl version -d|cut -d\" -f2)/certs/$(openssl x509 -hash -noout -in /var/lib/puppet/ssl/certs/ca.pem).0

You should be able to restart nginx and issue

    puppet:~# puppet agent --test --noop

with no problems to report. The final message output will be:

    Exiting; no certificate found and waitforcert is disabled

This means that the puppet agent did make a connection to the puppet master
server but rejected sending any catalogs down as the key presented by the client
was unknown to the server: you must sign the certificate.

    puppet:~# puppet cert --sign puppet.troutwine.us
    notice: Signed certificate request for puppet.troutwine.us
    notice: Removing file Puppet::SSL::CertificateRequest puppet.troutwine.us at '/var/lib/puppet/ssl/ca/requests/puppet.troutwine.us.pem'

(Your fully qualified domain will vary. See the help text of `puppet cert` for
more details.) To bring the base system up to speed, note the output of

    puppet:~# cat /var/lib/puppet/ssl/certs/ca.pem

then, on the base system,

    base:~# mkdir -p /var/lib/puppet/ssl/certs
    base:~# chown puppet:puppet /var/lib/puppet/ssl/certs/
    base:~# cat << EOF >> /var/lib/puppet/ssl/certs/ca.pem
    YOUR CERTIFICATE KEY TEXT GOES HERE
    EOF
    base:~# chmod 644 /var/lib/puppet/ssl/certs/ca.pem
    base:~# ln -s /var/lib/puppet/ssl/certs/ca.pem $(openssl version -d|cut -d\" -f2)/certs/$(openssl x509 -hash -noout -in /var/lib/puppet/ssl/certs/ca.pem).0

Every system cloned from the base _from this point forward_ will be keyed to the
created puppet master key. That means, should the master key change you'll need to
manually swap them on every live host and update the base image.

## What have we got and where to next?

<div class="poetry">
<pre>
Venerable Gon'yo asked Joshu,
  "How is it when a person does not have a single thing?"
Joshu said,
  "Throw it away."
Gon'yo said,
  "I say I don't have a single thing. What could I ever throw away?"
Joshu said,
  "If so, carry it around with you."
</pre>
<small>Gon'yo's One "Thing"</small>
</div>

We have a little more than nothing to carry around, happily. What we do have is
a pre-configured base system coupled to a central puppet master, though with no
version control of puppet manifests, no puppet manifests and nothing to ensure
that puppet is _actually_ doing the job we set for it to do. That's all fixable.

In the next article we'll accomplish three things:

* version controlled manifests,
* the self-hosting of puppet and
* the tech needed to get a more convenient deployment model going.

Articles thereafter will cover the inclusion of ops management tools, including:

* [Puppet Dashboard](http://docs.puppetlabs.com/dashboard/manual/1.2/bootstrapping.html) and
* Redmine.

Happy hacking!
