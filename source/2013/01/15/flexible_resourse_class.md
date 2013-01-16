---
title: Adaptable REST resource model in Ruby.
tags: ruby, software development, REST
---

Infrastructure services: it's what I do now. The primary service I work on is
FireEngine, previously mentioned in this blog. It's a network device abstraction
service, all bristling with Erlang goodness and RESTful delights. My team
actively supports and develops three other major projects in addition, two of
which are co-eternal with FireEngine. One of _these_--which will go unnamed as
there's been no official public comment on it--is a business process serving
client of FireEngine. It's a studiously object-oriented
[Rails Prime](http://words.steveklabnik.com/rails-has-two-default-stacks),
[rails-api](https://github.com/rails-api/rails-api) kind of application, the
brain-child of my colleague Josh Schairbaum
([@jschairb](https://twitter.com/jschairb)).

READMORE

The great thing about my group's work, and especially the unnamed application
mentioned, is that we know what we produce will run in production for years,
possibly decades. It behooves us, then, to be sure of the software's internal
design, to have flexible modeling of the domain and to have maintainable
code. We have _a lot_ of conversations around code and how it fits into our
overall goals.

This comes to mind as last week Schairbaum produced this (somewhat sanitized by
me):

    DATA = {
        "links" => { "self" => {"rel"=>"self", "href"=>"https://internal-api.example.com/switches/foo/neighbors"},
        "switch" => {"rel"=>"up", "href"=>"https://internal-api.example.com/switches/foo"}},
        "items" => [ {"name"=>"bar", "href"=>"/switches/bar", "interface_id"=>10101},
                     {"name"=>"baz", "href"=>"/switches/baz", "interface_id"=>10102} ]
    }

    class Neighbors
      attr_accessor :hostname
      attr_reader   :data

      def attributes
        { "hostname" => hostname }.merge(data)
      end

      def initialize(hostname, fetch=true)
        self.hostname = hostname
        initialize_data(fetch)
      end

      def method_missing(method, *args, &block)
        data.keys.include?(method.to_s) ? data[method.to_s] : super
      end

      def respond_to?(method)
        data.keys.include?(method.to_s) || super
      end

      def to_s
        attributes.inspect
      end

      private
      # Assume DATA is a call to an external service
      def initialize_data(fetch)
        @data = fetch ? DATA : {}
      end
    end

    neighbors = Neighbors.new(hostname)
    neighbors.items # -> [ {"name"=>"bar", "href"=>"/switches/bar", "interface_id"=>10101},
                    #      {"name"=>"baz", "href"=>"/switches/baz", "interface_id"=>10102} ]

with the following comment:

> I like the flexibility, but I'm not sure I like the implicitness, although the
> API documentation for FireEngine has the explicit fields.

It's a neat implementation. If ruby isn't a language you speak here are the main
points:

 * `@data` holds the deserialized representation of a remote FireEngine REST
   resource,
 * `#method_missing` allows the object to respond to any method whose name is
   a key in `@data`, returning the value of that key and
 * `#attributes` will return the hash data we've dredged up--or smuggled in via
   `DATA`--and add in the hostname, as well.

With this implementation `Neighbors` will change as the underlying service does,
without need for code updates. I like this; I'm a fan of the dynamism of this
approach. Of this code Schairbaum asked:

> The major question: is it important to be explicit about all the attributes
> that a class could have with that class is directly derived from an existing
> API call?

As is so often the case when I answer something, I enumerated opposite points of
view:

## No.

As this class was written specifically to model a FireEngine resource, the
downstream consumer probably needs to know something of FireEngine anyway;
documentation on this object that refers to the FireEngine documentation will
probably be Good Enough. Users of the library as a whole are likely, for the
time being, to be FireEngine domain experts--or know a few--and the uncertainty
I pointed out above will be irrelevant so long as all interested parties are
aware of changes in the underlying API. This implementation removes the burden
of maintaining an explicit mapping to the underlying service.

## Yes.

Downstream consumers of this class are forced to have explicit knowledge of the
underlying service's data model. That, or the consumer will instantiate the
object a few times, pick out the attributes they want and hope everything's
stable. The hope-and-pray approach is possible when the underlying service has
some sort of support for versioning, which this implementation does not provide
facility for. There's no way to determine from this implementation what
attributes instantiated objects will have merely by reading the code. Aside from
'hostname', there are no guarantees offered by this implementation at
all. Without written documentation--an assertion of a minimal attribute set, if
only in written form--it is hard for a downstream consumer to Not Be Surprised.

## How I really felt: No.

No, we don't have to be explicit about the attributes in a class derived from a
well-known API call _in this case_. That is, while the object and its library
are used solely in my team and closely related teams the implicit behavior is
acceptable. There is tacit knowledge of teammates to fall back on and everyone
is assumed to be savvy enough that while we _have_ handed you a shotgun it's
probably not a _great_ idea to point it at your foot. Throw in some
documentation to give a minimal interface and you're even further along to
something that could be released to a more general programming audience. Add in
API versioning--and this could be implemented simply in a real `Neighbor`--the
implicit interface of this object would be stable and the object is now ready
for popular consumption.

You have here a base that can easily be polished in a gentle, iterative way.

Schairbaum followed up after I had my spiel with a nice compromise:

> I also thought about meeting in the middle, which is being explicit about the
> most "important" attributes, yet falling back to method_missing for the rest.

Explicit functions provide some meta-data on the underlying API to those ignorant
of it, granting a greater degree of discoverability. Not bad.
