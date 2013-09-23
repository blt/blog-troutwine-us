---
title: Making Trivial Erlang/OTP Releases With Relx
tags: erlang, software development, tools
---

Thanks to [Tristan Sloughter](https://twitter.com/t_sloughter) and his recent
[work on relx](https://github.com/erlware/relx/pull/29) making an Erlang/OTP
no-downtime release is now super, super trivial. Like, so trivial you should
just go ahead and plan to do it.

In this article I'm going to assume you're pretty familiar with Erlang but
haven't made any no-downtime releases yet and aren't _quite_ sure where to
start.

READMORE

- - -

**EDIT (September 23, 2013)**: This article targets relx version
[0.2.0](https://github.com/erlware/relx/releases/tag/0.2.0). As of 0.3.0 the
syntax for upgrading/downgrading has changed to be simply `install VSN_NUMBER`.
This change thanks to [Richard Jones](https://twitter.com/metabrew).

- - -

## On no-downtime releases

I've got two special terms to introduce. An Erlang "application" is synoymous to
an
[OTP Application](http://www.erlang.org/doc/design_principles/applications.html)
and is akin to a bundled library in other languages. An Erlang "release" is a
set of "applications" deployed and running together.[^clusternote] A no-downtime
release is a swap between two releases, the current running release and one
prepared and loaded. The really neat part is this swap can be performed without
interrupting the service of the system: you don't need to 'pause' the system;
you can perform a live upgrade[^ordowngrade] of a running system without any
user being the wiser. There are three parts to doing this successfully:

 1. designing your system to be release-ready,
 1. building release tarballs for a running system and
 1. performing the steps to swap releases on a running system.

It used to be that points two and three were the most difficult:
[release_handler](http://www.erlang.org/doc/man/release_handler.html) and
[systools](http://www.erlang.org/doc/man/systools.html) are older and have
assumptions that, without context, seem peculiar. These tools are, if not
difficult, immensely tedious to use and hard to teach. Relx, as we'll get to
shortly, does away with all of that. What's left is to cover point 1, which is
not so hard to do.

## Designing for OTP releases

How, then, does one design a system for releases? There are more than a few
moving pieces that the
[OTP Design Principles Guide](http://www.erlang.org/doc/design_principles/des_princ.html)
does a really great job laying out, but it's easy to get overwhelmed. To that
end, I have a dirt simple project [`beat`](https://github.com/blt/beat) which
should help. `beat` consists of two applications:

 * [beat_core](https://github.com/blt/beat/tree/0c25d4f7aae25a3111b8971a7d029b845088ce5a/apps/beat_core)
 * [beat_tcp_api](https://github.com/blt/beat/tree/0c25d4f7aae25a3111b8971a7d029b845088ce5a/apps/beat_core)

The application `beat_tcp_api` uses the [ranch](https://github.com/extend/ranch)
TCP acceptor pool library to listen for TCP connections on port 27182--as
hard-coded in `beat_tcp_api_sup.erl`. On connection, a `bta_protocol.erl`
handler is given the connection details, which, being a `gen_server`, it stores
in its state. On [server
init](https://github.com/blt/beat/blob/0c25d4f7aae25a3111b8971a7d029b845088ce5a/apps/beat_tcp_api/src/bta_protocol.erl#L47)
the `bta_protocol` kicks itself into an immediate timeout and then [registers
with
`beat_core`](https://github.com/blt/beat/blob/0c25d4f7aae25a3111b8971a7d029b845088ce5a/apps/beat_tcp_api/src/bta_protocol.erl#L64).
After registering with `beat_core`, the server will receive a `{beat,
integer()}` message periodically and will send the integer back to the user
across the TCP connection[^alsochat]. `beat_tcp_api` is, ultimately, not
terribly interesting. There's no logic here. It exists to decouple the
`beat_core` application via a protocol from interface details.

As to `beat_core`, the primary module of interest is
[`beat_core_beater`](https://github.com/blt/beat/blob/a2620c93e7982d11315167dd087fe09f09ab1e57/apps/beat_core/src/beat_core_beater.erl).
Examining its
[state definition](https://github.com/blt/beat/blob/a2620c93e7982d11315167dd087fe09f09ab1e57/apps/beat_core/src/beat_core_beater.erl#L13)
you'll find the `linked_procs` lists, which is where the TCP connection owning
processes are ultimately registered. Some neat things are done with
[`erlang:monitor/2`](http://erlang.org/doc/man/erlang.html#monitor-2) but of
primary interest is the interplay of the definition of
[`code_change/3`](https://github.com/blt/beat/blob/a2620c93e7982d11315167dd087fe09f09ab1e57/apps/beat_core/src/beat_core_beater.erl#L85)
and the state of the beater in any given release. That is, the module takes
pains to keep its running state timeout synced to the state record definition at
the top of the module. The
[`beat_core.appup`](https://github.com/blt/beat/blob/a2620c93e7982d11315167dd087fe09f09ab1e57/apps/beat_core/ebin/beat_core.appup)
uses the "advanced" configuration option to pass `from1to2` in the case of
upgrade from `beat_core` versions "2013.1" to "2013.2" and `from2to1` when going
the other way. These atoms are not OTP defaults; they are data I manually pass
into the last argument of `code_change/3` via the
[application's appup](https://github.com/blt/beat/blob/a2620c93e7982d11315167dd087fe09f09ab1e57/apps/beat_core/ebin/beat_core.appup).
Doing this is very valuable for keeping release state changes straight, a
technique I originally encountered
[here](http://www.metabrew.com/article/erlangotp-releases-rebar-release_handler-appup-etc).

The initial `beat` release is named 0.1.0. When upgrading `beat_core` to 2013.2
I decided to issue a new `beat` release, 0.1.1. The diff to make this
happen--going from commit
[9f5b1ce7](https://github.com/blt/beat/commit/9f5b1ce764f0d0542ce0ac6b9eb813efc8bfbee1)
to
[e586a529](https://github.com/blt/beat/commit/a2620c93e7982d11315167dd087fe09f09ab1e57)--turns
out to be relatively small. You can see it
[here](https://github.com/blt/beat/compare/9f5b1ce764f0d0542ce0ac6b9eb813efc8bfbee1...a2620c93e7982d11315167dd087fe09f09ab1e57).

The careful reader will notice that I corrected a bug in the beater's
`change_code/3`, but the principle is the same[^reminder].

- - -

**EDIT (September 14, 2013)**: As pointed out by
[Per Melin](https://twitter.com/pmelin) on Twitter[^noappupdiff], the above diff
is missing the most vital asset of the whole process: the `beat_core` appup.
That's absolutely my fault; the development of `beat` was rather tortured. You
_must_ include an [appup file](http://www.erlang.org/doc/man/appup.html) in the
release applications' ebin directories. Here's
[`apps/beat_core/ebin/beat_core.appup`](https://github.com/blt/beat/blob/a2620c93e7982d11315167dd087fe09f09ab1e57/apps/beat_core/ebin/beat_core.appup):

    {"2013.2",
        [{"2013.1", [
            {update,beat_core_beater,{advanced,[from1to2]}}
        ]}],
        [{"2013.1",[
            {update,beat_core_beater,{advanced,[from2to1]}}
        ]}]
    }.

Simple stuff for `beat`. Per Melin also noted that I am "glossing over the
arguably trickiest part: the appup," and that "[f]or non-trivial apps you must
also specify module deps and more."[^glossingover] I didn't get into it here
because, well, `beat` is intentionally a trivial app.

Please be advised, complicated applications can and probably will have
complicated appups. The
[Appup Cookbook](http://www.erlang.org/doc/design_principles/appup_cookbook.html)
has more.

- - -

The main take-away here is that a well managed upgrade is deliberate
manipulation of state across releases and some grunt work bumping version
numbers here and there. No more.

## Doing Releases with Relx

Rather that walk you through how releases _used_ to be done I'm just going to go
ahead and blow your mind. I'm going to assume you've got a local clone of
`beat`, you'll be running commands initially from there and have installed relx
in your path. Build the initial release of beat and get it running as a
background node:

    > git checkout v1
    Switched to branch 'v1'
    > make clean && make
    ...

    > relx release tar
    Starting relx build process ...
    Resolving OTP Applications from directories:
        /Users/blt/projects/us/troutwine/beat/apps
        /Users/blt/projects/us/troutwine/beat/deps
        /Users/blt/.kerl/installs/R15B03/lib

    Resolving available releases from directories:
        /Users/blt/projects/us/troutwine/beat/apps
        /Users/blt/projects/us/troutwine/beat/deps
        /Users/blt/.kerl/installs/R15B03/lib

    Resolved beat-0.1.0
    release successfully created!
    tarball /Users/blt/projects/us/troutwine/beat/_rel/beat-0.1.0.tar.gz successfully created!

The `_rel` created by relx will hold a ready and runnable copy of beat version
0.1.0 and a beat-0.1.0.tar.gz deployable to any location. We'll run a background
node on the local machine:

    > mkdir /tmp/beat
    > cp _rel/beat-0.1.0.tar.gz /tmp/
    > cd /tmp/beat
    > tar xf /tmp/beat-0.1.0.tar.gz

There's now enough on-disk to create the background node:

    > /tmp/beat/bin/beat start
    ok
    > /tmp/beat/bin/beat ping
    pong

Connect a telnet client on port 27182 to see the stream of integers beat
creates.

    > telnet localhost 27182
    13
    14
    15

They'll come one per second. Keep your telnet connection open and head back to
the beat project root. We'll create the relup for beat version 0.1.1:

    > git checkout v2
    Switched to branch 'v2'
    > make clean && make
    ...

    > relx release relup tar
    Starting relx build process ...
    Resolving OTP Applications from directories:
        /Users/blt/projects/us/troutwine/beat/apps
        /Users/blt/projects/us/troutwine/beat/deps
        /Users/blt/.kerl/installs/R15B03/lib
        /Users/blt/projects/us/troutwine/beat/_rel

    Resolving available releases from directories:
        /Users/blt/projects/us/troutwine/beat/apps
        /Users/blt/projects/us/troutwine/beat/deps
        /Users/blt/.kerl/installs/R15B03/lib
        /Users/blt/projects/us/troutwine/beat/_rel

    Resolved beat-0.1.1
    release successfully created!
    relup successfully created!
    tarball /Users/blt/projects/us/troutwine/beat/_rel/beat-0.1.1.tar.gz successfully created!

The addition of the 'relup' command instructs relx to build the necessary files
to drive the built-in OTP upgrade mechanism. There will be a beat-0.1.1.tar.gz
which we'll have to move to the deployment area to the place that Erlang
expects. Per the
[Release Structure](http://www.erlang.org/doc/design_principles/release_structure.html#id76047)
chapter of the _OTP Design Principles_ we'll have to place this tarball in
`releases/VSN` of the deployment area. In our case it's as simple as:

    > mkdir /tmp/beat/releases/0.1.1
    > cp _rel/beat-0.1.1.tar.gz /tmp/beat/releases/0.1.1/beat.tar.gz

Here's the upgrade:

    > /tmp/beat/bin/beat upgrade "0.1.1/beat"
    Unpacked Release "0.1.1"
    Installed Release "0.1.1"
    Made Release "0.1.1" Permanent

You'll now see that the integers are coming across at 1/10th the speed and that
your connection _was not_ lost, nor was the count of the server at all
destroyed.

You can attach to your node to confirm the release version:

    > /tmp/beat/bin/beat attach
    Attaching to /tmp/erl_pipes/beat/erlang.pipe.1 (^D to exit)

    (beat@127.0.0.1)1> release_handler:which_releases().
    [{"beat","0.1.1",
      ["kernel-2.15.3","stdlib-1.18.3","beat_core-2013.2",
       "ranch-0.8.5","beat_tcp_api-2013.1","sasl-2.2.1"],
      permanent},
     {"beat","0.1.0",[],old}]

Wham and that's it! It's an uninterrupted upgrade of a live system in a few
simple steps. Easy enough to be completely automated, simple enough to perform
to be taught directly, rather than hiding OTP releases away at the end of books'
Advanced Topics chapter.

[^noappupdiff]: [https://twitter.com/pmelin/status/378886746231939072](https://twitter.com/pmelin/status/378886746231939072)

[^glossingover]: [https://twitter.com/pmelin/status/378885781286178816](https://twitter.com/pmelin/status/378885781286178816)

[^clusternote]: I originally wrote "together on the same VM" but Erlang
clustering makes this not true. A release consisting of applications `A` and `B`
across clustered nodes `N` and `M` can have `A` run on `N` and `B` run on `M`.
Fun!)

[^ordowngrade]: Or downgrade!

[^alsochat]: `bta_protocol` will also echo messages back to the user. `beat` was
originally intended as a project to teach OTP principles to intermediate Erlang
programmers. See the project's [Issues](https://github.com/blt/beat/issues) for
more, if you're interested in learning by building a IRC-like chat server.

[^reminder]:  Also, remember that `timer:seconds/1` and co. are super useful.
