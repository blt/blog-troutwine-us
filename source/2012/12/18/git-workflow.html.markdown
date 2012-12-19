---
title: Track  upstream in a branch, or, my git workflow.
tags: git, workflow, software development, Rackspace
---

In my work at Rackspace with the FDaAT git features heavily. My group's rate of
development is fairly rapid: it is not atypical for our projects to receive
multiple pull requests in a day, in addition to the work I'm doing. How I keep
my changes separated from an evolving codebase without falling behind involves a
particular bit of bookkeeping.

READMORE

Before I explain what that is, I should note that our projects follow a fairly
typical canonical master repository / development fork model. Take
[FireEngine](http://www.rackspace.com/blog/how-rackspace-is-using-erlang/) as an
example. We've got the `fdaat/fire_engine` canonical repo into which all code is
pull-request merged and from which deployments are made; developer repositories
get commits to feature branches and these feature branches become pull-requests
against `fdaat/fire_engine`'s master branch. (If pull requests are a new thing
to you, here's how github describes
[them](https://help.github.com/articles/using-pull-requests). Note they use the
term 'fork & pull' for the model I'm discussing.)

When I issue a pull request I want github to be able to merge my commits
automatically. For this to happen, especially if my feature branch lives for
more than a day, I have to integrate the commits from the canonical master
branch that went up after I made my initial branch.

This is what I do.

## I work out of a local development repository.

In a development repository anything goes: force pushes, screwy rebases, erasure
of commits you subsequently think better of. No one is inconvenienced if a
development repository sees bad code or bad actions. That's why whenever I to
join in on a new project I make a remote fork of the canonical repository and
clone _my_ fork locally. Like so:

    git clone git@github.rackspace.com:blt/fire_engine.git fire_engine

The master of local fire_engine tracks that of `blt/fire_engine`.

## I track canonical master in a read-only branch.

I call this branch upstream and create it like so:

    $ git remote add upstream git://github.rackspace.com/fdaat/fire_engine.git
    $ git fetch --all
    $ git checkout -b upstream upstream/master

Now local upstream tracks canonical master and I can get any new commits into
canonical from this branch.

Why read-only? Accidents happen.

## Before I start a feature branch, rebase from upstream.

It's more simple to sync with upstream before beginning a feature than it is to
do so after some development effort has passed. I never make commits directly
into local master, preferring it to be an exact replica of canonical
master. (Why? Consider the difficulty of committing to local master if you're
working two or more features at a time.) Here's how I sync with upstream:

    $ git checkout upstream && git pull
    $ git checkout master && git rebase upstream

At this point local master is exactly canonical master. The branch off this is
what you'd expect:

    $ git checkout -b super_new_feature

## Before wrapping up with a pull request, sync with upstream again.

Once `super_new_feature` has everything you'd want, but just before making a
pull-request, I sync with upstream again to be sure there will be no merge
conflicts.

    $ git checkout upstream && git pull
    $ git checkout super_new_feature && git rebase upstream

The difference here that I've synced into `super_new_feature` and not
master. I skip master, and so my local master often lags behind until it's time
to make a new feature branch.

## Ship it!

That's that. After a successful sync the feature branch is ready to submit as a
pull request that'll merge successfully. It's a simple approach that works out
well in practice.
