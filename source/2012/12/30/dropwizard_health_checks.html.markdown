---
title: Dropwizard's Health Checks, Metrics and Operation Focus
tags: java, operations, software development, dropwizard
---

I got a chance, finally, to play with Yammer's
[Dropwizard](http://dropwizard.codahale.com/) a bit this weekend. It's an
interesting library/mini-framework that does so very much to showcase the best
of RESTful API development in Java, sans all the Object Oriented Dark Ages
ride-alongs: not much XML beyond `pom.xml`, _very_ clear documentation and
[example code](https://github.com/codahale/dropwizard/tree/master/dropwizard-example)
for ready study.

What I came away most impressed with were the nods to the needs of Operations in
the base library: specifically,
[health checks](http://dropwizard.codahale.com/manual/core/#health-checks) and
[metrics](http://metrics.codahale.com/getting-started/).

READMORE

## Health checks, you say?

At boot a Dropwizard application server starts listening on two ports, one it
calls admin; by default, it's 8081. The GET'able `/healthcheck` resource returns
a list of all pass/fail statuses of the checks registered in the Dropwizard
environment. Each check, a subclass of `com.yammer.metrics.core.HealthCheck`, is
really just an object wrapped healthy/unhealty `check()` function. Unhealthy
checks can wrap strings to act as messages. Checks are largely defined by the
developer, though some of the dropwizard libraries come with their own. Module
[dropwizard-db](http://mvnrepository.com/artifact/com.yammer.dropwizard/dropwizard-db)
comes with health checks for the database connection pool it manages.

The health checks are such a simple thing, but I like them very much for two
reasons:

* The presence of health checks put the concerns of deployment operations at
  least partially in mind during the purely development phase of a project.
* The list presented by `/healthchecks` is such a simple thing, yet it gives
  immediate insight into the state of an application server.

With regard to the last point, you'll surely have to consult with logs to
determine the full context of a fault in an application server, but if you
encode enough preparatory material into health checks, bam, you're further along
in debugging for an amortizing cost.

## Metrics make the world go round.

Dropwizard's other fancy bit is tight integration with metrics, which, as you
might at least partially guess, is an annotations based metrics collection
library. Where health checks are coarse, metrics gives you fine-grained numeric
data with which to jam. The default Dropwizard strategy for analyzing this data
seems to be to hook JMX up to the application server, but there's support for a
wider range of
[common tools](http://metrics.codahale.com/manual/core/#reporters).

Metric collection and monitoring in general is a tricky in that, rather like
testing, it's a perpetual journey. There's always more to learn _about_ your
creation, either for correctness' sake--fixing bugs before they inconvenience
end users--or for operations management, just keeping the application alive and
online. Dropwizard's most valuable contribution, to my mind, is it's bundling
of monitoring tools into the very core of the library, rather than somewhere off
on the periphery ecosystem. That's a certainly a strong statement of principle.

It will be interesting to see how Dropwizard evolves.
