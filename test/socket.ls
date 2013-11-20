should = (require \chai).should!
{mk-pgrest-fortest} = require \./testlib
io-client = require "socket.io-client"

require! \express
pgrest = require \..

socket-url = 'http://localhost:8080'

var _plx, plx, app, socket
describe 'Socket' ->
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

    socket := io-client.connect socket-url, {transports: ['websocket'], 'force new connection': true}
    socket.on \error ->
      throw it
    
    unless app
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
      done!
    else
      done!
  afterEach (done) ->
    <- plx.query """
    DROP TABLE IF EXISTS foo;
    DROP TABLE IF EXISTS bar;
    """
    socket.disconnect!
    done!
  describe 'with public schema' ->
    describe 'GET:#table', -> ``it``
      .. 'should get all entries in the table', (done) ->
        socket.emit "GET:foo", ->
          it.entries[0].should.deep.eq { _id: 1, bar: 'test' }
          it.entries[1].should.deep.eq { _id: 2, bar: 'test2' }
          done!
      .. 'should work on any table', (done) ->
        socket.emit "GET:bar", ->
          it.entries[0].should.deep.eq { _id: 1, info: 't1' }
          it.entries[1].should.deep.eq { _id: 2, info: 't2' }
          done!
      .. 'should work with query params', (done) ->
        socket.emit "GET:foo", { q: '{"_id":1}' }, ->
          it.paging.count.should.eq 1
          it.entries[0].should.deep.eq { _id: 1, bar: 'test' }
          done!
      .. 'should be able to get entry with specified _id', (done) ->
        socket.emit "GET:foo", { _id: 1 }, ->
          it.should.deep.eq { _id: 1, bar: 'test'}
          done!
      .. 'should be able to return the column of the entry with specified _id', (done) ->
        socket.emit "GET:foo", { _id: 1, _column: "bar" }, ->
          it.should.deep.eq "test"
          done!
    describe 'POST:#table', -> ``it``
      .. 'should insert entry to table', (done) ->
        socket.emit "POST:foo", { body: { _id: 3, bar: 'new'}}, ->
          it.should.deep.eq [1]
          cols <- plx.query "SELECT * FROM foo"
          cols.length.should.eq 3
          cols[2].should.deep.eq { _id:3, bar: "new"}
          done!
    describe 'DELETE:#table', -> ``it``
      .. 'should delete all entries in the table', (done) ->
        socket.emit "DELETE:foo", ->
          it.should.eq 2
          cols <- plx.query "SELECT * FROM foo"
          cols.should.deep.eq []
          done!
      .. 'should be able to remove entry with specified _id', (done) ->
        socket.emit "DELETE:foo", { _id: 1 }, ->
          it.should.eq 1
          cols <- plx.query "SELECT * FROM foo WHERE _id=1"
          cols.length.should.eq 0
          done!
    describe 'PUT:#table', -> ``it``
      .. 'should replace entries in the table', (done) ->
        socket.emit "PUT:foo", { body: { _id: 2, bar: 'replaced'}}, ->
          it.should.deep.eq [1]
          cols <- plx.query "SELECT * FROM foo"
          cols.should.deep.eq [{ _id:2, bar: 'replaced'}]
          done!
      .. 'should upsert entries in the table', (done) ->
        socket.emit "PUT:foo", { body: { _id: 2, bar: 'upserted'}, u: true}, ->
          it.should.deep.eq { updated: true }
          cols <- plx.query "SELECT * FROM foo WHERE _id=2"
          cols[0].should.deep.eq { _id:2, bar: 'upserted'}
          done!
      .. 'should be able to upsert entry with specified _id', (done) ->
        socket.emit "PUT:foo", { _id: 1, body: { _id: 1, bar: 'upserted'} }, ->
          it.should.deep.eq { updated: true }
          cols <- plx.query "SELECT * FROM foo WHERE _id=1"
          cols[0].should.deep.eq { _id:1, bar: 'upserted'}
          done!
  describe 'Subscription' ->
    describe 'SUBSCRIBE:#table:value', -> ``it``
      .. 'should create trigger and return OK', (done) ->
        <- socket.emit "SUBSCRIBE:foo:value"
        done!
    describe 'SUBSCRIBE:#table:child_added', -> ``it``
      .. 'should receive snapshot if triggered', (done) ->
        socket.on 'foo:child_added' ->
          it.should.deep.eq { _id: 3, bar: 'new'}
          done!
        <- socket.emit "SUBSCRIBE:foo:child_added"
        <- socket.emit "POST:foo", { body: { _id: 3, bar: 'new'}}
    describe 'SUBSCRIBE:#table:child_removed', -> ``it``
      .. 'should receive snapshot if triggered', (done) ->
        socket.on 'foo:child_removed' ->
          it.should.deep.eq { _id: 1, bar: 'test'}
          done!
        <- socket.emit "SUBSCRIBE:foo:child_removed"
        <- socket.emit "DELETE:foo", { _id: 1 }
    describe 'SUBSCRIBE:#table:child_changed', -> ``it``
      .. 'should receive snapshot if triggered', (done) ->
        socket.on 'foo:child_changed' ->
          it.should.deep.eq { _id: 2, bar: 'replaced'}
          done!
        <- socket.emit "SUBSCRIBE:foo:child_changed"
        <- socket.emit "PUT:foo", { _id: 1, body: { _id: 2, bar: 'replaced'}}
    describe 'SUBSCRIBE:#table:value', -> ``it``
      .. 'should receive snapshot if triggered', (done) ->
        socket.on 'foo:value' ->
          it.length.should.eq 3
          it[0].should.deep.eq { _id: 1, bar: 'test'}
          it[1].should.deep.eq { _id: 2, bar: 'test2'}
          it[2].should.deep.eq { _id: 3, bar: 'new'}
          done!
        <- socket.emit "SUBSCRIBE:foo:value"
        <- socket.emit "POST:foo", { body: { _id: 3, bar: 'new'}}



