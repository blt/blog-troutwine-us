---
title: "The Utility of Erlang Records: Where They Should and Probably Shouldn't be Replaced by Maps"
tags: erlang, associative structures
---

There are two kinds of associations common in software:

0. A fixed mapping from a set of pre-defined names to values.
0. A dynamic mapping from a type domain to another.

As an example of the first, consider C structs or Haskell data declarations with
named fields. You have a finite set of names--known at compile time--which
map--at runtime--to some values. Languages like Haskell with their fancy
Hindley–Milner type systems can make more compile-time guarantees about the
_types_ of values but all the languages I'm aware of which have this sort of
static association at least disallow--at compile-time--referencing a name which
doesn't exist in the mapping. In Erlang, this sort of static association is
called a ['record'](http://www.erlang.org/doc/reference_manual/records.html).

READMORE

Erlang records are defined ahead of use so the compiler can enforce constraints.
To whit:

    -record(topic, {subscribers = []           :: pid(),
                    msg_backlog = []           :: [term()],
                    created     = erlang:now() :: os:timestamp()}).

Here we have an association--called `topic`--of the names `subscribers`,
`msg_backlog` and `created` to process IDs, a list of arbitrary Erlang terms and
a timestamp, respectively. The Erlang compiler can ensure that the programmer
never references a, say, `does_not_exist` element of the `topic` record and all
code which touches this record may be written to assume these three fields or
crash, failing this.

The second sort is the classic "associative array" which many languages provide
as a built-in type. Ruby, for instance:

    topic = {
              :subscribers => [],
              :msg_backlog => [],
              :created     => Time.now()
            }

This looks, superficially at least, very similar. The Erlang record definition
has some type information--via
[typespecs](http://www.erlang.org/doc/reference_manual/typespec.html)--but it's
the same sort of data in a similar name to value pairing. The key difference
here is that the keys present in the initial declaration may be destroyed and
new ones can be added. The associative array is a container for and is in itself
data, rather than being merely a container.

Up until R17, Erlang, like C, didn't have a first-class associative array. The
language had implementations--[dict](http://www.erlang.org/doc/man/dict.html)
and [gb_trees](http://www.erlang.org/doc/man/gb_trees.html) for example--but
these didn't admit pattern matching (a big deal) and they weren't particularly
fast or space efficient (less of a big deal, but still). With R17, though, a new
"maps" type
[has been introduced](http://joearms.github.io/2014/02/01/big-changes-to-erlang.html)
and now we can do things like:

    Topics = #{subscribers => [],
               msg_backlog => [],
               created     => erlang:now()}.

This has similar semantics to the Ruby code above: dynamic keys in the structure
and no ahead-of-time pedantry about non-existent names being referenced.

The primary distinction between the two varieties of associations is the static
nature of the fixed mapping. Being fixed, both the compiler and the programmer
can make stronger assumptions about the shape of data being passed around in a
program. The associative array might--just maybe--have had a key removed or
snuck in due to a bug. Sometimes this matters, sometimes it doesn't but you'll
have to check to find out.

In many languages we're living without these stronger assumptions, quite
happily. Python's dictionary is not paired with a C-style
struct--[struct](http://docs.python.org/2/library/struct.html) not
withstanding--and there's no immutable object in the base language that would be
a superset of a fixed mapping. Erlang's focus on reliability and fail-fast
philosophy make this problematic. If history were backward and maps had been
introduced first we would see a fair bit of pattern matching used to assert the
existence, rather than the values, of fields because you can't be sure if
they're there or not. This is already a problem after hot-updates. Record
definitions change and old record data, not updated to the newer format, cause
crashes through the updated, running system. Dynamic associations allow every
code path to sneak this in on you.

Joe's piece, referenced above, says:

> Records are dead - long live maps !

I tend to think this is somewhat tongue in cheek. (I could be wrong.) In those
instances where you, the programmer, _known_ that your structure will _always_
have the same named fields and never any more, then the record remains the
correct structure to use (though, I agree, some actual runtime inspection would
be lovely). In those instances where your structure will have varying keys then
the map is your new best friend.

I expect, in practice, eventually, to see many fewer instances of proplists,
replaced by maps once the initial "replace all the records!" euphoria dies down
a bit. I know _I_ am going to be passing a number of options arguments as maps
once R17 is widely used enough in production. I further expect to see many
large, unwieldy records hidden behind accessor modules converted to maps as
these modules already take care of the integrity of the data. Intra-application,
I expect records will remain largely untouched. (Inter-application records are a
form of wicked tight coupling, but that's another post.)

In short:

- Static, known static fields? Use a record.
- Dynamic, potentially unknown fields? Use a map.
