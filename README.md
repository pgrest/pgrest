pgrest
======

[![Build Status](https://travis-ci.org/clkao/pgrest.png?branch=master)](https://travis-ci.org/clkao/pgrest)

WARNING: this is work in progress and everything is likely to change!

# PgREST is...

* a JSON document store
* running inside PostgreSQL
* working with existing relational data
* capable of loading Node.js modules
* compatible with MongoLab's REST API

Want to learn more? See the [https://github.com/clkao/pgrest/wiki](wiki).

# Installation

You need to install the plv8js extension for postgresql.  See [Installation](https://github.com/clkao/pgrest/wiki/Installation) for details.  PostgreSQL 9.0 is required.  We recommend using 9.2.

Once you are have plv8js. use npm to install pgrest:

    % npm i -g pgrest

When installing from git checkout, make sure you do `npm i` before `npm i -g .`

# Trying pgrest:

    % psql test
    test=# CREATE TABLE foo (id int, info json);
    CREATE TABLE
    test=# INSERT INTO foo VALUES (1, '{"f1":1,"f2":true,"f3":"Hi I''m \"Daisy\""}');
    INSERT 0 1

    % pgrest --db test
    Serving `test` on http://127.0.0.1:3000/collections

You can now access foo content with http://127.0.0.1:3000/collections/foo

## Reading:

    curl http://127.0.0.1:3000/collections/foo?q={"id":1}

The parameter is similar to MongoLab's REST API for listing documents:
https://support.mongolab.com/entries/20433053-rest-api-for-mongodb

## Writing:

    echo '{"id": 5,"info": {"counter":5} }' | curl -D - -H 'Content-Type: application/json' -X POST -d @- http://localhost:3000/collections/foo

# Socket.io

PgREST can handle socket.io connection with --websocket flag

    pgrest --db test --websocket

You can connect to PgREST with socket.io-client.
All REST api is exposed to socket.io client as well. check [test](test/socket.ls) for usage.

    <script src="http://HOST:PORT/socket.io/socket.io.js"></script>

    <script>
    var socket = io.connect('http://HOST:PORT');
    socket.on("complete", function (data) {
      // data = REST API return value
    });
    socket.emit("GET:foo");
    </script>
    
More importantly, socket.io client can subscribe to a collection. Any new item being inserted into the collection will notify the client.

    var socket = io.connect('http://HOST:PORT');
    s.on("CHANNEL:foo", function (data) {
      // called every time something is inserted into foo
    });
    s.emit("SUBSCRIBE:foo");

# PgBase

PgBase is an attempt to built a firebase-compatible API on top of PgREST

    var ref = new PgBase("http://127.0.0.1:3000/foo");
    ref.on("child_added", function(it) {
        $("#log").append(it.info.bar);
    });

    ref.push({_id:3, info: { bar: "Ke"}});

check out example/pgbase/pgbase.html and client/ref.ls for some infomation.

Document coming soon.

# Developing

## Runing test:

```
createdb test
export TESTDBUSERNAME=postgres # optional
export TESTDBNAME=test
npm i
npm run test
```

# Additional web server support

In addition to the bundled `pgrest` frontend, you can also use the following frontend:

* Perl: [Plack::App::PgREST](https://github.com/clkao/Plack-App-PgREST)
* Using ngx_postgres (experimental)
