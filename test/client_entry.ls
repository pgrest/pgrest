should = (require \chai).should!
{mk-pgrest-fortest} = require \./testlib
pgclient = require "../client/ref" .Ref

require! \express
pgrest = require \..

socket-url = 'http://localhost:8080'

var _plx, plx, app, client, server
describe 'Websocket Client on Entry' ->
  this.timeout 10000ms
  beforeEach (done) ->
    _plx <- mk-pgrest-fortest!
    plx := _plx
    <- plx.query """
    DROP TABLE IF EXISTS foo;
    CREATE TABLE foo (
      _id int,
      bar text
    );
    DROP TABLE IF EXISTS bar;
    CREATE TABLE bar (
      _id int,
      info text
    );
    INSERT INTO foo (_id, bar) values(1, 'test');
    INSERT INTO foo (_id, bar) values(2, 'test2');
    INSERT INTO bar (_id, info) values(1, 't1');
    INSERT INTO bar (_id, info) values(2, 't2');
    """

    {mount-default,with-prefix} = pgrest.routes!
    {mount-socket} = pgrest.socket!
    app := express!
    app.use express.cookieParser!
    app.use express.json!
    server := require \http .createServer app
    io = require \socket.io .listen server, { log: false}
    server.listen 8080

    cols <- mount-socket plx, null, io
    client := new pgclient "#socket-url/foo/1", {force: true }

    done!
  afterEach (done) ->
    <- plx.query """
    DROP TABLE IF EXISTS foo;
    DROP TABLE IF EXISTS bar;
    """
    client.disconnect!
    done!
  describe 'Ref is on a entry', ->
    describe "Reference", -> ``it``
      .. 'should have correct ref type', (done) ->
        client.refType.should.eq \entry
        done!
    describe "Reading values", -> ``it``
      .. 'should be able to get the entry via \'value\' event', (done) ->
        client.on \value ->
          it.should.deep.eq { _id: 1, bar: \test }
          done!
    describe "Setting values", -> ``it``
      .. '.set should replace the entry', (done) ->
        client.set { _id: 1, bar: "replaced" }
        client.on \value, ->
          it.should.deep.eq { _id: 1, bar: \replaced }
          done!
      .. '.set should work without _id param', (done) ->
        <- client.set { bar: \replaced }
        cols <- plx.query "SELECT * FROM foo"
        for c in cols
          if c._id == 1
            c.should.deep.eq { _id: 1, bar: \replaced }
          else if c.id == 2
            c.should.deep.eq { _id: 2, bar: \test2}
        done!
      .. '.set should only replace the entry', (done) ->
        <- client.set { _id: 1, bar: \replaced }
        cols <- plx.query "SELECT * FROM foo"
        for c in cols
          if c._id == 1
            c.should.deep.eq { _id: 1, bar: \replaced }
          else if c.id == 2
            c.should.deep.eq { _id: 2, bar: \test2}
        done!
    describe "Updating value", -> ``it``
      .. '.update should replace the entry', (done) ->
        client.update { _id: 1, bar: \replaced }
        client.on \value, ->
          it.should.deep.eq { _id: 1, bar: \replaced }
          done!
      .. '.update should work without _id param', (done) ->
        <- client.update { bar: \replaced }
        cols <- plx.query "SELECT * FROM foo"
        for c in cols
          if c._id == 1
            c.should.deep.eq { _id: 1, bar: \replaced }
          else if c.id == 2
            c.should.deep.eq { _id: 2, bar: \test2}
        done!
      .. '.update should only replace the entry', (done) ->
        <- client.update { _id: 1, bar: \replaced }
        cols <- plx.query "SELECT * FROM foo"
        for c in cols
          if c._id == 1
            c.should.deep.eq { _id: 1, bar: \replaced }
          else if c.id == 2
            c.should.deep.eq { _id: 2, bar: \test2}
        done!
    describe "Removing values", -> ``it``
      .. '.remove should clear the entry', (done) ->
        <- client.remove
        col <- plx.query "SELECT * FROM foo WHERE _id=1;"
        col.length.should.eq 0
        done!
    describe "Removing listener", -> ``it``
      .. '.off should remove all listener on a specify event', (done) ->
        client.on \value, ->
          client.socket.listeners(\foo:child_changed).length.should.eq 1
          client.off \value
          client.socket.listeners(\foo:child_changed).length.should.eq 0
          done!
      .. '.off can remove specified listener on a event', (done) ->
        cb = ->
          client.socket.listeners(\foo:child_changed).length.should.eq 1
          client.off \value, cb
          client.socket.listeners(\foo:child_changed).length.should.eq 0
          done!
        client.on \value, cb
    describe "Once callback", -> ``it``
      .. '.once callback should only fire once', (done) ->
        <- client.once \value
        client.socket.listeners(\foo:child_changed).length.should.eq 0
        done!
    describe "toString", -> ``it``
      .. ".toString should return absolute url", (done) ->
        client.toString!should.eq "http://localhost:8080/foo/1"
        done!
    describe "root", -> ``it``
      .. ".root should return host url", (done) ->
        client.root!should.eq "http://localhost:8080"
        done!
    describe "name", -> ``it``
      .. ".name should return table name", (done) ->
        client.name!.should.eq 1
        done!
    var parent
    describe "parent", -> ``it``
      beforeEach (done) ->
        parent := client.parent!
        done!
      afterEach (done) ->
        parent.disconnect!
        done!
      .. ".parent should return host", (done) ->
        parent.refType.should.eq \collection
        parent.once \value ->
          it.length.should.eq 2
          done!
    var child
    describe "child", -> ``it``
      beforeEach (done) ->
        child := client.child("bar")
        done!
      afterEach (done) ->
        child.disconnect!
        done!
      .. ".child should return column", (done) ->
        child.refType.should.eq \column
        child.once \value, ->
          it.should.eq \test
          done!

