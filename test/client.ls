should = (require \chai).should!
{mk-pgrest-fortest} = require \./testlib
pgclient = require "../client/client" .Ref

require! \express
pgrest = require \..

socket-url = 'http://localhost:8080'

var _plx, plx, app, client
describe 'Websocket Client' ->
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
    server = require \http .createServer app
    io = require \socket.io .listen server, { log: false}
    server.listen 8080

    cols <- mount-default plx, null, with-prefix '/collections', -> app.all.apply app, &
    cols <- mount-socket plx, null, io
    client := new pgclient("#socket-url/foo")

    done!
  afterEach (done) ->
    <- plx.query """
    DROP TABLE IF EXISTS foo;
    DROP TABLE IF EXISTS bar;
    """
    client.socket.disconnect!
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
    describe "Setting values", -> ``it``
      .. '.set should replace the whole collection', (done) ->
        client.set { _id: 1, bar: "replaced" }
        client.on \value, ->
          it.length.should.eq 1
          done!
      .. '.set should be able to replace the collection with multiple entries', (done) ->
        client.set [{ _id: 1, bar: "replaced" }, { _id: 2, bar: "replaced" }]
        client.on \value, ->
          it.length.should.eq 2
          done!
      .. '.set should trigger child_added event', (done) ->
        <- client.on \child_added ->
          it.should.deep.eq { _id: 1, bar: \replaced }
          done!
        client.set { _id: 1, bar: "replaced" }
      .. '.set should trigger child_removed event', (done) ->
        <- client.on \child_removed, ->
          # _id = 2 will trigger this too
          if it._id == 1
            done!
        client.set { _id: 1, bar: "replaced" }
    describe "Pushing values", -> ``it``
      .. '.push should add new entry to collection', (done) ->
        client.push { _id: 3, bar: \insert }
        client.on \value, ->
          it.length.should.eq 3
          done!
      .. '.push should trigger child_added event', (done) ->
        <- client.on \child_added, ->
          done!
        client.push { _id: 3, bar: \inesrt }
    describe "Removing values", -> ``it``
      .. '.remove should clear the collection', (done) ->
        client.remove!
        client.on \value, ->
          it.length.should.eq 0
          done!
      .. '.remove should trigger child_removed event', (done) ->
        <- client.on \child_removed, ->
          # _id = 2 will trigger this too
          if it._id == 1
            done!
        client.remove!

