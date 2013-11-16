should = (require \chai).should!
{mk-pgrest-fortest} = require \./testlib
io-client = require "socket.io-client"

require! \express
pgrest = require \..

socket-url = 'http://localhost:8080'

var _plx, plx, app
describe 'Socket' ->
  this.timeout 5000ms
  beforeEach (done) ->
    _plx <- mk-pgrest-fortest!
    plx := _plx
    <- plx.query """
    DROP TABLE IF EXISTS foo;
    CREATE TABLE foo (
      id int,
      bar text
    );
    INSERT INTO foo (id, bar) values(1, 'test');
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
        socket.on \error ->
          throw it
        socket.on "GET:foo" ->
          it.entries[0].should.deep.eq { id: 1, bar: 'test' }
          done!
        socket.emit "GET:foo"
    describe 'GET:#table with query param', -> ``it``
      .. 'should work', (done) ->
        socket = io-client.connect socket-url, {transports: ['websocket'], 'force new connection': true}
        socket.on \error ->
          throw it
        socket.on "GET:foo" ->
          it.paging.count.should.eq 1
          it.entries[0].should.deep.eq { id: 1, bar: 'test' }
          done!
        socket.emit "GET:foo", { q: '{"id":1}' }
    
    describe 'POST:#table', -> ``it``
      .. 'should insert entry to table', (done) ->
        socket = io-client.connect socket-url, {transports: ['websocket'], 'force new connection': true}
        socket.on \error ->
          throw it
        socket.on "POST:foo" ->
          it.should.deep.eq [1]
          done!
        socket.emit "POST:foo", { body: { id: 2, bar: 'haha'}}
    describe 'DELETE:#table', -> ``it``
      .. 'should delete all entries in the table', (done) ->
        socket = io-client.connect socket-url, {transports: ['websocket'], 'force new connection': true}
        socket.on \error ->
          throw it
        socket.on "DELETE:foo" ->
          it.should.eq 1
          done!
        socket.emit "DELETE:foo"
    describe 'PUT:#table', -> ``it``
      .. 'should replace entries in the table', (done) ->
        socket = io-client.connect socket-url, {transports: ['websocket'], 'force new connection': true}
        socket.on \error ->
          throw it
        socket.on "PUT:foo" ->
          it.should.deep.eq [1]
          done!
        socket.emit "PUT:foo", { body: { id: 2, bar: 'haha'}}
    describe 'PUT:#table with upsert', -> ``it``
      .. 'should replace entries in the table', (done) ->
        socket = io-client.connect socket-url, {transports: ['websocket'], 'force new connection': true}
        socket.on \error ->
          throw it
        socket.on "PUT:foo" ->
          it.should.deep.eq { updated: true }
          done!
        socket.emit "PUT:foo", { body: { id: 2, bar: 'haha'}, u: true}
    
