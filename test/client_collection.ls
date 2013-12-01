should = (require \chai).should!
{mk-pgrest-fortest} = require \./testlib
pgclient = require "../client/ref" .Ref

require! \express
pgrest = require \..

socket-url = 'http://localhost:8080'

var _plx, plx, app, client, server
describe 'Websocket Client on Collection' ->
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
    client := new pgclient "#socket-url/foo", { force: true }

    done!
  afterEach (done) ->
    <- plx.query """
    DROP TABLE IF EXISTS foo;
    DROP TABLE IF EXISTS bar;
    """
    client.disconnect!
    done!
  describe 'Ref is on a collection', ->
    describe "Reference", -> ``it``
      .. 'should have correct ref type', (done) ->
        client.refType.should.eq \collection
        done!
    describe "Reading values", -> ``it``
      .. 'should be able to get all entries via \'value\' event', (done) ->
        client.on \value ->
          it.length.should.eq 2
          done!
    describe "Events", -> ``it``
      .. 'should trigger \'value\' when pushed', (done) ->
        client.once \value ->
          if it.length == 3
            done!
        client.push { _id: 3, bar: \insert }
    describe "Setting values", -> ``it``
      .. '.set should replace the whole collection', (done) ->
        <- client.set { _id: 1, bar: "replaced" }
        client.on \value, ->
          it.length.should.eq 1
          done!
      .. '.set should be able to replace the collection with multiple entries', (done) ->
        <- client.set [{ _id: 1, bar: "replaced" }, { _id: 2, bar: "replaced" }]
        client.on \value, ->
          it.length.should.eq 2
          done!
      .. '.set should trigger child_added event', (done) ->
        client.on \child_added ->
          it.should.deep.eq { _id: 1, bar: \replaced }
          done!
        client.set { _id: 1, bar: "replaced" }
      .. '.set should trigger child_removed event', (done) ->
        client.on \child_removed, ->
          # _id = 2 will trigger this too
          if it._id == 1
            done!
        client.set { _id: 1, bar: "replaced" }
    describe "Pushing values", -> ``it``
      .. '.push should add new entry to collection', (done) ->
        <- client.push { _id: 3, bar: \insert }
        client.on \value, ->
          it.length.should.eq 3
          done!
      .. '.push should trigger child_added event', (done) ->
        client.on \child_added, ->
          done!
        client.push { _id: 3, bar: \inesrt }
      .. '.push should trigger value event', (done) ->
        client.once \value, ->
          if it.length == 3
            done!
        client.push { _id:3, bar: \insert }
    describe "Removing values", -> ``it``
      .. '.remove should clear the collection', (done) ->
        <- client.remove!
        <- client.on \value, ->
          it.length.should.eq 0
          done!
      .. '.remove should work if collection has value trigger on it', (done) ->
        value_trigger = ->
          if it.length == 0
            client.off \value, value_trigger
            done!
        client.on \value, value_trigger
        client.remove!
      .. '.remove should work if collection has child_added trigger on it', (done) ->
        client.on \child_added, ->
        <- setTimeout _, 100ms
        client.remove!
        done!
      .. '.remove should work if collection has child_removed trigger on it', (done) ->
        client.on \child_removed, ->
          if it._id == 1
            done!
        client.remove!
      .. '.remove can provide a callback to know when completed', (done) ->
        <- client.remove
        done!
      .. '.remove should trigger child_removed event', (done) ->
        client.on \child_removed, ->
          # _id = 2 will trigger this too
          if it._id == 1
            done!
        client.remove!
    describe "Removing listener", -> ``it``
      .. '.off should remove all listener on a specify event', (done) ->
        client.on \value, ->
          client.socket.listeners(\foo:value).length.should.eq 1
          client.off \value
          client.socket.listeners(\foo:value).length.should.eq 0
          done!
      .. '.off can remove specified listener on a event', (done) ->
        cb = ->
          client.socket.listeners(\foo:value).length.should.eq 1
          client.off \value, cb
          client.socket.listeners(\foo:value).length.should.eq 0
          done!
        client.on \value, cb
    describe "Once callback", -> ``it``
      .. '.once callback should only fire once', (done) ->
        client.once \child_added, ->
          client.socket.listeners(\foo:child_added).length.should.eq 0
          done!
        client.socket.listeners(\foo:child_added).length.should.eq 1
        client.push { _id:3, bar: \inserted }
    describe "toString", -> ``it``
      .. ".toString should return absolute url", (done) ->
        client.toString!should.eq "http://localhost:8080/foo"
        done!
    describe "root", -> ``it``
      .. ".root should return host url", (done) ->
        client.root!should.eq "http://localhost:8080"
        done!
    describe "name", -> ``it``
      .. ".name should return table name", (done) ->
        client.name!.should.eq \foo
        done!
    var child
    describe "child", -> ``it``
      beforeEach (done) ->
        child := client.child(1)
        done!
      afterEach (done) ->
        child.disconnect!
        done!
      .. ".child should return a ref point to entry", (done) ->
        child.refType.should.eq \entry
        child.on \value, ->
          it.should.deep.eq { _id: 1, bar: \test }
          done!
