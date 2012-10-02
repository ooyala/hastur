## What Is It?

Hastur is a monitoring system written by Ooyala.  It uses Cassandra for time series storage, resulting in
remarkable power, flexibility and scalability.

Hastur works hard to make it easy to add your data and easy to get it back at full resolution.  For instance,
it makes it easy to query in big batches from a REST server, build a dashboard of metrics, show errors in
production or email you when an error rate gets too high.

This gem helps you get your data into Hastur.  See the "hastur-server" gem for the back end, and for how to
get your data back out.

## How Do I Use It?

Install this gem (`gem install hastur`) or add it to your app's Gemfile and run `bundle`.

Add Hastur calls to your application, such as:

    Hastur.counter "my.thing.to.count"               # Add 1 to my.thing.to.count
    Hastur.gauge "other.thing.foo_latency", 371.1    # Record a latency of 371.1

You can find extensive per-method documentation in the source code, or see "Is It Documented?" below for
friendly HTML documentation.

This is enough to instrument your application code, but you'll need to install a local daemon and have a
back-end collector for it to talk to.  See the hastur-server gem for specifics.

Hastur allows you to send at regular intervals using Hastur.every, which will call a block from a background
thread:

    @total = 0
    Hastur.every(:minute) { Hastur.gauge("total.counting.so.far", @total) }
    loop { sleep 1; @total += 1 }  # Count one per second, send it once per minute

The YARD documentation (see below) has far more specifics.

## Is It Documented?

We use YARD.  `gem install yard redcarpet`, then type `yardoc` from this source directory.  This will generate
documentation -- point a browser at [doc/index.html](doc/index.html) for the top-level view.

## Mechanism

Your messages are automatically timestamped in microseconds, labeled and converted to a JSON structure for
transport and storage.

Hastur sends the JSON over a local UDP socket to a local "Hastur Agent", a daemon that forwards your data to
the shared Hastur servers. That means that your application will never slow down for Hastur -- failed sends
become no-ops.  Note that local UDP won't randomly drop packets like internet UDP, though you can lose them if
there's no Hastur Agent running.

The Hastur Agent forwards the messages to Hastur Routers over [ZeroMQ](http://0mq.org).  The routers send it
to the sinks, which preprocess your data, index it and write it to Cassandra.  They also forward to the
syndicators for the streaming interface (e.g. to email you if there's a problem).

Cassandra is a highly scalable clustered key-value store inspired somewhat by Amazon Dynamo.  It's a lot of
the "secret sauce" that makes Hastur interesting.

## Hints and Tips

1.  You can retrieve messages with the same name prefix all together from the REST API (for instance:
    `my.thing.*`).  It's usually a good idea to give metrics the same prefix if you will retrieve them at the
    same time.  This prefix syntax is very efficient for Cassandra.  That's why we made it easy to use.

2.  Every call allows you to pass labels - a one-level string-to-string hash of tags about what that call
    means and what data goes with it. For instance, you might call:

        Hastur.gauge "my.thing.total_latency", 317.4, :now, :units => "usec"

    Eventually you'll be able to query messages by label through the REST interface, but for now that's
    inconvenient.  However, it's easy to subscribe to labels in the streaming interface.  So labels are a
    powerful way to mark data as being interesting to alert you about.

    For example:

        Hastur.gauge "my.thing.total_latency", 317.4, :now, :severity => "omg!"

    It's easy to subscribe to any latency with a severity label in the streaming interface, which would let
    you calculate how bad the overall latency pretty well.  See the hastur-server gem for details of the
    trigger interface.

3.  You can group multiple messages together by giving them the same timestamp.  For instance:

        ts = Hastur.timestamp
        Hastur.gauge "my.thing.latency1", val1, ts
        Hastur.gauge "my.thing.latency2", val2, ts
        Hastur.counter "my.thing.counter371", 1, ts

    This makes it easy to query all events with exactly that timestamp and the same prefix (`my.thing.*`), and
    otherwise to make sure they're exactly the same.

    Do **not** give multiple messages the same name **and** the same timestamp.  Hastur will only store a
    single event with the same name and timestamp from the same node.  If you give several of them the same
    name and timestamp, you'll lose all but one.

    Keep in mind that timestamps are in microseconds -- you're not limited to one event with the same name per
    second.
