---
title: Ternary Search Trie in Erlang
date: 2012/04/29
tags: erlang, data structures
---

The last few months I've not done a terrible amount hobby programming; I spent
much of the time interviewing (successfully!) at Rackspace and, since arriving
in San Antonio, have been busy learning the team code-base. There were a _few_
hobby projects I finished during February-April period, the one I'm most pleased
with is a [ternary search
trie](http://en.wikipedia.org/wiki/Ternary_search_tree), a data-structure
described by Bentley and Sedgewick in their 1996 paper [Fast Algorithms for
Searching and Sorting
Strings](http://www.cs.tufts.edu/~nr/comp150fp/archive/bob-sedgewick/fast-strings.pdf), among other places.

READMORE

I wrote an implementation from the paper with the intention of writing a
Scrabble bot around it, but I'll probably not finish that project. I'm releasing
the code, extracted from the Scrabble bot under the MIT license. Find it on
[Github](https://github.com/blt/tst). Novel features:

* extensively typed
* uses [proper](https://github.com/manopapad/proper) to test algorithm properties

Problems:

* works only on strings, as typed
* never stress tested nor optimized for performance
* the work of idle hands, not necessarily careful

Patches welcome!
