should = (require \chai).should!
{mk-pgrest-fortest} = require \./testlib
io-client = require "socket.io-client"

require! \express
pgrest = require \..

socket-url = 'http://localhost:8080'

var _plx, plx, app
describe 'Socket' ->
  beforeEach (done) ->
    _plx <- mk-pgrest-fortest!
    plx := _plx
    <- plx.query """
    DROP TABLE IF EXISTS foo;
    CREATE TABLE foo (
      _id int,
      bar text
    );
    INSERT INTO foo (_id, bar) values(1, 'test');
    INSERT INTO foo (_id, bar) values(2, 'test2');
    """

    unless app
      {mount-default,mount-socket,with-prefix} = pgrest.routes!
      app := express!
      app.use express.cookieParser!
      app.use express.json!
      server = require \http .createServer app
      io = require \socket.io .listen server
      io.set 'log level', 1
      server.listen 8080

      cols <- mount-default plx, null, with-prefix '/collections', -> app.all.apply app, &
      cols <- mount-socket plx, null, io
      done!
    else
      done!
  afterEach (done) ->
    <- plx.query """
    DROP TABLE IF EXISTS foo;
    """
    done!
  describe 'with public schema' ->
    # TODO: need refactoring
    describe 'GET:#table', -> ``it``
      .. 'should get all entries in the table', (done) ->
        socket = io-client.connect socket-url, {transports: ['websocket'], 'force new connection': true}
        socket.on "GET:foo" ->
          it.entries[0].should.deep.eq { _id: 1, bar: 'test' }
          it.entries[1].should.deep.eq { _id: 2, bar: 'test2' }
          done!
        socket.emit "GET:foo"
    describe 'GET:#table with query param', -> ``it``
      .. 'should work', (done) ->
        socket = io-client.connect socket-url, {transports: ['websocket'], 'force new connection': true}
        socket.on "GET:foo" ->
          it.paging.count.should.eq 1
          it.entries[0].should.deep.eq { _id: 1, bar: 'test' }
          done!
        socket.emit "GET:foo", { q: '{"_id":1}' }
    describe 'POST:#table', -> ``it``
      .. 'should insert entry to table', (done) ->
        socket = io-client.connect socket-url, {transports: ['websocket'], 'force new connection': true}
        socket.on "POST:foo" ->
          it.should.deep.eq [1]
          cols <- plx.query "SELECT * FROM foo"
          cols.length.should.eq 3
          cols[2].should.deep.eq { _id:3, bar: "new"}
          done!
        socket.emit "POST:foo", { body: { _id: 3, bar: 'new'}}
    describe 'DELETE:#table', -> ``it``
      .. 'should delete all entries in the table', (done) ->
        socket = io-client.connect socket-url, {transports: ['websocket'], 'force new connection': true}
        socket.on "DELETE:foo" ->
          it.should.eq 2
          cols <- plx.query "SELECT * FROM foo"
          cols.should.deep.eq []
          done!
        socket.emit "DELETE:foo"
    describe 'PUT:#table', -> ``it``
      .. 'should replace entries in the table', (done) ->
        socket = io-client.connect socket-url, {transports: ['websocket'], 'force new connection': true}
        socket.on "PUT:foo" ->
          it.should.deep.eq [1]
          cols <- plx.query "SELECT * FROM foo"
          cols.should.deep.eq [{ _id:2, bar: 'replaced'}]
          done!
        socket.emit "PUT:foo", { body: { _id: 2, bar: 'replaced'}}
    describe 'PUT:#table with upsert', -> ``it``
      .. 'should upsert entries in the table', (done) ->
        socket = io-client.connect socket-url, {transports: ['websocket'], 'force new connection': true}
        socket.on "PUT:foo" ->
          it.should.deep.eq { updated: true }
          cols <- plx.query "SELECT * FROM foo WHERE _id=2"
          cols[0].should.deep.eq { _id:2, bar: 'upserted'}
          done!
        socket.emit "PUT:foo", { body: { _id: 2, bar: 'upserted'}, u: true}
    describe 'GET:#table with _id param', -> ``it``
      .. 'should get entry with specified _id', (done) ->
        socket = io-client.connect socket-url, {transports: ['websocket'], 'force new connection': true}
        socket.on "GET:foo" ->
          it.should.deep.eq { _id: 1, bar: 'test'}
          done!
        socket.emit "GET:foo", { _id: 1 }
    describe 'PUT:#table with _id param', -> ``it``
      .. 'should upsert entry with specified _id', (done) ->
        socket = io-client.connect socket-url, {transports: ['websocket'], 'force new connection': true}
        socket.on "PUT:foo" ->
          it.should.deep.eq { updated: true }
          cols <- plx.query "SELECT * FROM foo WHERE _id=1"
          cols[0].should.deep.eq { _id:1, bar: 'upserted'}
          done!
        socket.emit "PUT:foo", { _id: 1, body: { _id: 1, bar: 'upserted'} }
    describe 'DELETE:#table with _id param', -> ``it``
      .. 'should remove entry with specified _id', (done) ->
        socket = io-client.connect socket-url, {transports: ['websocket'], 'force new connection': true}
        socket.on "DELETE:foo" ->
          it.should.eq 1
          cols <- plx.query "SELECT * FROM foo WHERE _id=1"
          cols.length.should.eq 0
          done!
        socket.emit "DELETE:foo", { _id: 1 }

