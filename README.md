pgrest
======

[![Build Status](https://travis-ci.org/clkao/pgrest.png?branch=master)](https://travis-ci.org/clkao/pgrest)

WARNING: this is work in progress and everything is likely to change!

# Slides in lieu of a proper documentation

<http://www.audreyt.org/newdict/jekyller/_public/>

The first section describes plv8x, and the later sections has some real-world
examples such as:

<http://www.audreyt.org/newdict/jekyller/_public/?full#pgrest-mongolab-api-server>

# PgREST is...

* a JSON document store
* running inside PostgreSQL
* working with existing relational data
* capable of loading Node.js modules
* compatible with MongoLab's REST API

# Install plv8js extension for postgresql

Note: Requires postgresql 9.1 or later.  9.0 will be supported soon.

```
# for older distros: sudo add-apt-repository ppa:martinkl/ppa
sudo apt-get install libv8-dev

sudo easy_install pgxnclient
sudo pgxn install plv8
```

# Try pgrest:

```
npm i
npm run prepublish

./node_modules/.bin/plv8x --db tcp://localhost/MYDB --import pgrest:./package.json
./node_modules/.bin/plv8x --db tcp://localhost/MYDB --inject 'plv8x_json pgrest_select(plv8x_json)=pgrest:pgrest_select'

# then this will give you json representation of "sometable":
MYDB=$ select pgrest_select('{"collection": "sometable", "l": 10}');
```

The parameter is similar to MongoLab's REST API for listing documents:
https://support.mongolab.com/entries/20433053-rest-api-for-mongodb

# Web server support

* Perl: [Plack::App::PgREST](https://github.com/clkao/Plack-App-PgREST)
