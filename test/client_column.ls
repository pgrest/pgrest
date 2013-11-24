should = (require \chai).should!
assert = (require \chai).assert
{mk-pgrest-fortest} = require \./testlib
pgclient = require "../client/client" .Ref

require! \express
pgrest = require \..

socket-url = 'http://localhost:8080'

var _plx, plx, app, client, server
describe 'Websocket Client on Column' ->
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
    client := new pgclient("#socket-url/foo/1/bar")

    done!
  afterEach (done) ->
    console.log \init-after
    <- plx.query """
    DROP TABLE IF EXISTS foo;
    DROP TABLE IF EXISTS bar;
    """
    client.socket.disconnect!
    server.close!
    console.log \done-after
    done!
  describe 'Ref is on a collection', ->
    describe "Reference", -> ``it``
      .. 'should have correct ref type', (done) ->
        client.refType.should.eq \column
        done!
    describe "Reading values", -> ``it``
      .. 'should be able to get specified column via \'value\' event', (done) ->
        client.on \value ->
          it.should.eq "test"
          done!
    describe "Setting values", -> ``it``
      .. '.set should replace the column', (done) ->
        client.set "replaced"
        client.on \value, ->
          it.should.eq \replaced
          done!
    describe "Updating value", -> ``it``
      .. '.update should replace the column', (done) ->
        client.set "replaced"
        client.on \value, ->
          it.should.eq \replaced
          done!
    describe "Removing values", -> ``it``
      .. '.remove should set the column to undefined', (done) ->
        client.remove!
        client.on \value, ->
          assert.isNull it
          done!
      .. '.remove can provide a callback to know when completed', (done) ->
        <- client.remove
        done!
    describe "Removing listener", -> ``it``
      .. '.off should remove all listener on a specify event', (done) ->
        client.on \value, ->
          # an empty callback
        client.socket.listeners(\foo:child_changed).length.should.eq 1
        client.off \value
        client.socket.listeners(\foo:child_changed).length.should.eq 0
        done!
      .. '.off can remove specified listener on a event', (done) ->
        cb1 = ->
          #empty callback
        cb2 = ->
          #empty callback2
        client.on \value, cb1
        client.on \value, cb2
        client.socket.listeners(\foo:child_changed).length.should.eq 2
        client.off \value, cb1
        client.socket.listeners(\foo:child_changed).length.should.eq 1
        done!
    describe "Once callback", -> ``it``
      .. '.once callback should only fire once', (done) ->
        client.once \value, ->
          # should fire only once
        # wait once callback finish
        <- setTimeout _, 100ms
        client.socket.listeners(\foo:child_changed).length.should.eq 0
        done!
    describe "toString", -> ``it``
      .. ".toString should return absolute url", (done) ->
        client.toString!should.eq "http://localhost:8080/foo/1/bar"
        done!
    describe "root", -> ``it``
      .. ".root should return host url", (done) ->
        client.root!should.eq "http://localhost:8080"
        done!
    describe "name", -> ``it``
      .. ".name should return table name", (done) ->
        client.name!.should.eq \bar
        done!
    describe "parent", -> ``it``
      .. ".parent should return host", (done) ->
        client.parent!should.eq "http://localhost:8080/foo/1"
        done!

