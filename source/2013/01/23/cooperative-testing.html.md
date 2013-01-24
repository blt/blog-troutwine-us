---
title: Cooperative Functional Testing of REST APIs
tags: testing, software development
---

There's something I was told that's been flitting around my mind, paraphrased:
"Functional testing, done repeatedly, is pretty much monitoring." I'm not
_entirely_ convinced of the truth of this but it's got me thinking about how to
make a hypermedia-ish REST API cooperate with clients that want to assert
properties about it. Specifically, today, I wanted to check that the
representations of all resources in a staging API conformed to a schema and
iterate over all possible objects in the staging system.

I had two thoughts, but let's go over the problem domain first just so we're
clear.

READMORE

## The Problem

Let's say you have a service that provides an abstraction over physical hardware
devices, does SNMP queries for you, what have you. A request like so:

    GET /routers/rr_chi_22
    Accept: application/json

and you get json back that looks like:

    {
      "status": "okay",
      "model": "Super Impressive Router 3000",
      "online-since": "2010-01-22T05:05:33Z",
      "links": {
          "self": {
              "rel": "self",
              "href": "https://example.com/routers/rr_chi_22"
          },
          "routers": {
              "rel": "up",
              "href": "https://example.com/routers"
          },
          "neighbors": {
              "rel": "related",
              "href": "https://example.com/routers/rr_chi_22/neighbors"
          }
      }
    }

Okay? You get some data about the router immediately, a link to a sub-resource
and some other navigation details. Now, if you've swapping out something
important in the application that drives this API how do you ensure it still
does what you hope? You _should_ be doing fine-grained testing of the code's
modules, but how about the whole system, in a systematic way?

What you _should_ do is start another project--potentially bundled with your
application code, but probably not as your needs grow--that will hammer away on
a staging endpoint, hitting test host devices, asserting that data obeys the
contracts you've got with your clients. Being very, very explicit in the test
project about what schemas should look like, etc. drives you right into the
problem of having yet another needy client that has to be coordinated with as
development on the primary application progresses.

How do you create a test client that evolves as the API does while only needing
to minimally adapt it as the API grows?

## Some Think-Out-Loud Solutions

These two ideas below are inspired by the technique in the
[last post](http://blog.troutwine.us/2013/01/15/flexible_resourse_class.html),
specifically what needs to be done to provide for such an adaptive client.

### Advertise a schema for all resources.

The basic concern of most clients is going to be "Does the data coming out of
the API have the documented form?" XML APIs, as cumbersome as they can be, have
the advantage of having document type definitions baked right in. JSON APIs in
place of DTDs kind of sorta have
[`application/schema+json`](http://tools.ietf.org/html/draft-zyp-json-schema-03),
but a different media type for each resource is not discoverable, especially as
many current APIs don't support this type. I propose to keep the schema--which
is readily consumable--but put it under its own tree. For instance, the above
payload would include a link child:

    "schema": {
        "rel": "related",
        "href": "https://example.com/routers/id"
    }

Any client that cares can load the schema with another request and the
maintainers of the API should bake the schema into their test validation, so
that it won't tend to rot over time, as even the best documentation does.

### Provide private meta-data for select users.

We're writing a functional suite against the API and know that in the staging
environment we need to inspect the following hosts:

* rr_chi_22
* ra_or_9834
* rb_or_9834

That's not so bad. Hard-code them into the test client and go. The application
server will maintain its own list of the test routers for its own, internal
integration testing. Over time, just like zombies, more and more test devices
come and they don't stop. Eventually you have a synchronization problem, keeping
the knowledge of the client in sync with that of the application server.

To keep knowledge of the system centralized, I propose adding a meta-resource to
the application server, accessible only by certain users. For instance:

    GET /meta/test_servers
    Accept: application/json

and the response:

    {
      "items": [
          {
              "name": "rr_chi_22",
              "href": "https://example.com/routers/rr_chi_22"
          },
          {
              "name": "ra_or_9834",
              "href": "https://example.com/routers/ra_or_9834"
          },
          {
              "name": "rb_or_9834",
              "href": "https://example.com/routers/rb_or_9834"
          }
      ],
      "links": {
          "self": {
              "rel": "self",
              "href": "https://example.com/meta/test_servers"
          },
          "meta": {
              "rel": "up",
              "href": "https://example.com/meta"
          }
      }
    }

Now your appropriately credentialed clients can know exactly which test routers
to hit without having that knowledge hard-coded. You could even switch the
meta resource off in production.
