should = (require \chai).should!
{mk-pgrest-fortest} = require \./testlib

var _plx, plx
describe 'Protected resources', ->
  @timeout 10000ms
  beforeEach (done) ->
    _plx <- mk-pgrest-fortest meta:
      pgrest_protected:
        as: 'pgrest_test'
        rules: [
          * name: \pgrest_update
            event: \insert
            type: \also
            command: """
              SELECT ~> 'throw 403'
            """
        ]

    plx := _plx
    #@XXXX need to remove pgrest_boot
    <- plx.query """
    DROP TABLE IF EXISTS pgrest_test cascade;
    CREATE TABLE pgrest_test (
        field text not null primary key,
        value text[] not null,
        last_update timestamp
    );
    """
    pgrest = require \..
    <- pgrest.bootstrap plx, \dummy, process.cwd! + \/test/dummy.json
    done!
  afterEach (done) ->
    <- plx.query "DROP TABLE IF EXISTS pgrest_test cascade;"
    done!
  describe 'creates view' (,)-> it
    .. 'should have view', (done) ->
      res <- plx.query """select pgrest_select($1)""", [collection: \pgrest_protected]
      res.0.should.have.keys 'pgrest_select'
      res.0.pgrest_select.paging.count.should.eql 0
      done!
    .. 'should be able to insert to raw', (done) ->
      res <- plx.query """select pgrest_insert($1)""", [collection: \pgrest_test, $: [
        * field: \a, value: <[a b]>
      ]]
      res <- plx.query """select pgrest_select($1)""", [collection: \pgrest_protected]
      res.0.should.have.keys 'pgrest_select'
      res.0.pgrest_select.paging.count.should.eql 1
      done!
    .. 'should throw for protected resources', (done) ->
      <- plx.insert collection: \pgrest_protected, $: [
        * field: \a, value: <[a b]>
      ], _, -> it.should.match /403/; done!
      it.should.eq null
