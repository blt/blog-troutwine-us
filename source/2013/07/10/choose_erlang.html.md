---
title: When would you choose Erlang?
tags: erlang, software development
---

I'm one of the Lucky Few (thousand?) that get to work with Erlang
professionally. Lots of people I meet are interested in the language--or Elixir,
increasingly, though I happen to think [LFE](http://lfe.github.io/) should be
the new hotness--but have only used the language for small hobby projects or
just read some books. "What do you use Erlang for?" I get asked.

READMORE

## Of Syntax and Semantics

Let's address something first: Erlang's syntax is unusual. It's prolog inspired
(In fact, Erlang was initially implemented in Prolog. If you ask Joe Armstrong
nicely he'll give you some early Erlang/Prolog source.) and that shows. Function
arity matters and semi-colons abound. There is no assignment to variables in
Erlang, only binding and matching, so what from a C-family language would look
to be assignment isn't. The lack of destructive binding makes imperative Erlang
into a mess of `Var0`, `Var1` and `Var2` statements as variables are 'mutated'.
Conditionals are all total, so
[if statements](http://erlang.org/doc/reference_manual/expressions.html#id77029)
are just plain strange.
[Records](http://www.erlang.org/doc/reference_manual/records.html) are limited
in terms of introspection by the fact that they don't really exist at runtime
(let that sink in). I could probably go on, but, as one becomes unaware of a
close-friend's strong accent, I hardly notice these things anymore. (Except for
the limits of records.) Concerns about syntax all get ironed out in the learning
process and the real show here, the _semantics_ of Erlang, have been very
carefully crafted:

 * Pattern matching makes destructuring code/data simple to understand, concise
   and maintainable.
 * Pattern matching in function heads makes for clear and simple conditional
   computation; if it's describable in an ordered way, you can build functions
   to pull it all apart.
 * Lack of traditional shared memory means never having to reason about access
   patterns or locking. One 'shares' by passing messages between processes.
 * Combined with the above, lack of in-process concurrency means a process never
   has to be written to worry about being interrupted or interfering with
   itself.
 * Lack of mutable data denies the ability to cheat and message mutable
   references around. Further, all data remains invariant, making reasoning
   about your program simpler (if you find reasoning in a functional style
   simple, of course).
 * If process A sends a message to process B and B is alive, the message is
   guaranteed to arrive.
 * Messages pool in a per-process inbox in the order in which they were
   received. Messages may be selectively removed from the inbox by
   pattern-matching.
 * Message passing is blind to local/remote process distinctions. That is,
   intra-VM messaging is accomplished in the same way--from the point of view of
   the programmer--as inter-VM messaging.
 * Processes can 'link', receiving special messages when pairs crash.
 * Processes have a unique ID--called a PID--but may optionally be given a
   per-VM or per-cluster unique name.

The implications for implementation of Erlang VMs are sort of subtle to suss
out, but they allow:

 * __Soft-realtime, low-latency performance characteristics__: For instance,
   shared state means garbage-collection is a per-process endeavor, removing the
   sort of whole application pauses you see in other GC languages.
 * __High-concurrency__: With processes being all single-threaded, Erlang can
   schedule them as it sees fit.
 * __High-parallelism__: If you hand the Erlang scheduler some OS threads, it
   can schedule processes across these threads. The lack of shared-memory
   between processes means the scheduler does not have to concern itself with
   resolving lock conflicts among processes.
 * __Distributivity__: By teaching the VM to transparently send remote messages
   the Erlang programmer can zip messages back and forth across the network with
   no cognitive overhead.
 * __Fault-tolerance__: With process linking it is possible to handle crash
   messages and respawn the newly dead partner process.
 * __Zero-downtime deployments__: By swapping the process pointed to by a
   certain name, you can change the process that will receive messages without
   interrupting service (messages in-flight to the old process are guaranteed to
   arrive, mind).

## What Erlang is Good For

 * __Latency sensitive work__: If you need relatively strong bounds on response
   times Erlang can give you that.
 * __Throughput sensitive work__: Erlang won't necessarily beat other languages in
   time to process a single unit of work, but it'll outperform when you need to
   do thousands of units of work more or less at the same time. (Put another
   way, concurrent/parallel aggregate process performance has long been an
   optimization target, but not per-process performance.)
 * __Network services__: Erlang's
   [bit syntax](http://erlang.org/doc/reference_manual/expressions.html#id78513)
   makes dealing with binary and text protocols equally natural, plus you can be
   sure your service will stay online and responsive in the face of failure.
 * __Mission critical middleware__: Erlang's zero-downtime deployments,
   fault-tolerance and optimization focuses make for exceptionally reliable
   services (think messaging, queues, distributed locking, job batching etc
   etc).
 * __Purely functional algorithmic work__: Erlang doesn't get as much attention
   here as Haskell or Lisp, but pattern matching plus higher-order functions is
   just wonderful. Write a lexer sometime in Erlang over binaries. You'll be
   surprised out painless it is, even for complex for tokenizations.
 * __Shared-nothing parallel computation__: Message passing combined with parallel
   execution of processes make this very simple. (You don't, though, have much
   say in how things get scheduled.)
 * __Big-ish Embedded environments__: While Erlang is suitable to be deployed on
   big, beefy machines, it started out in small telephony switches and retains
   low-memory usage characteristics. Compared to, say, the JVM you'll be
   surprised what mischief you can get up to in a handful of megabytes. (Robert
   Virding has an LEGO robot running Erlang. [Video](http://vimeo.com/64642760)).

## What Erlang isn't Good For

 * __Short-run computing__: The Erlang VM is pretty quick to startup, but it's not that
   fast. If you start scripting in Erlang you'll notice the lag.
 * __CPU intensive work__: The Erlang VM is not optimized for this work and
   wall-clock performance can be pokey.
 * __Share-memory parallel computation__: There's no shared memory available.
 * End-user desktop deployments: A single-binary executable is, without an
   impressive hack, not possible.
 * __Meta-programming__: Erlang's got macros, but they're simple
   text-replacement macros. If your bag of tricks heavily relies on writing code
   to write code, Erlang's going to be tough.
 * __Glue-together style web application__: While producing a REST API in Erlang
   is pretty easy (see either [webmachine](https://github.com/basho/webmachine)
   or [cowboy](https://github.com/extend/cowboy)) there is no equivalent to,
   say, Rails. There are a few rails-alikes, but they are not backed by the same
   depth of libraries.

In general, really, Erlang is missing the depth of libraries other languages
enjoy. I could have thrown something to do with statistics up in the list owing
to the lack of something like, say, [numpy](http://www.numpy.org/). The library
choices you will have in Erlang will be limited--especially if you work outside
of the common niche--which may or may not be a problem, depending on what you're
producing. Be prepared to read some source code. There is no central index of
Erlang libraries, no Maven, but Github is a
[common stomping ground](https://github.com/search?q=language%3Aerlang&ref=cmdform).
