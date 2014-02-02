{mk-pgrest-fortest,create-test-table,cleanup-test-table} = require \./testlib

function skip_unless_pg93(plx, done, cb)
  rows <- plx.query "select version()"
  [_, pg_version] = rows.0.version.match /^PostgreSQL ([\d\.]+)/
  if pg_version < \9.3.0
    it.skip 'skipped for < 9.3', ->
    return done!
  cb!

var plx
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
    <- create-test-table plx
    pgrest = require \..
    <- pgrest.bootstrap plx, \dummy, process.cwd! + \/test/dummy.json
    done!
  afterEach (done) ->
    <- cleanup-test-table plx
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
      <- skip_unless_pg93 plx, done

      <- plx.insert collection: \pgrest_protected, $: [
        * field: \a, value: <[a b]>
      ], _, -> it.should.match /403/; done!
      it.should.eq null

describe 'Protected resources', ->
  @timeout 10000ms
  beforeEach (done) ->
    _plx <- mk-pgrest-fortest meta:
      pgrest_protected:
        as: 'pgrest_test'
        rules: [
          * name: \pgrest_insert
            event: \insert
            type: \also
            command: """
              SELECT ~> $$throw 403 unless require('pgrest').pgrest_param_get('auth') is 'secret'$$
            """
          * name: \pgrest_update
            event: \update
            type: \also
            command: """
              SELECT ~> $$throw 403 unless require('pgrest').pgrest_param_get('auth') is 'secret'$$
            """
        ]

    plx := _plx
    <- create-test-table plx
    pgrest = require \..
    <- pgrest.bootstrap plx, \dummy, process.cwd! + \/test/dummy.json
    done!
  afterEach (done) ->
    #<- cleanup-test-table plx
    done!
  describe 'simple view is updatable' (,)-> it
    .. 'denied by default', (done) ->
      <- skip_unless_pg93 plx, done
      <- plx.insert collection: \pgrest_protected, $: [
        * field: \a, value: <[a b]>
      ], _, -> it.should.match /403/; done!
      it.should.eq null
    .. 'allowed with secret key', (done) ->
      <- skip_unless_pg93 plx, done
      res <- plx.insert collection: \pgrest_protected, pgparam: {auth: \secret}, $: [
        * field: \a, value: <[a b]>
      ]
      res.should.be.deep.eq [1]
      res <- plx.upsert collection: \pgrest_protected, pgparam: {auth: \wrong}, q: {field: \a}, $: $set:
        value: <[c d]>
      , _, -> it.should.match /403/; done!
      console.log "not supposed to be here"
      res.should.be.null!

describe 'Protected resources via dummy', ->
  @timeout 10000ms
  beforeEach (done) ->
    _plx <- mk-pgrest-fortest authkey: \secret, meta:
      pgrest_protected:
        as: 'pgrest_test'
        rules: [
          * name: \pgrest_insert
            event: \insert
            type: \also
            command: """
              SELECT ~> $$throw 403 unless require('dummy').test!$$
            """
          * name: \pgrest_update
            event: \update
            type: \also
            command: """
              SELECT ~> $$throw 403 unless require('dummy').test!$$
            """
          * name: \pgrest_delete
            event: \delete
            type: \also
            command: """
              SELECT ~> $$throw 403 unless require('dummy').test!$$
            """
        ]

    plx := _plx
    <- create-test-table plx
    pgrest = require \..
    <- pgrest.bootstrap plx, \dummy, process.cwd! + \/test/dummy.json
    done!
  afterEach (done) ->
    #<- cleanup-test-table plx
    done!
  describe 'simple view is updatable' (,)-> it
    .. 'denied by default', (done) ->
      <- skip_unless_pg93 plx, done
      <- plx.insert collection: \pgrest_protected, $: [
        * field: \a, value: <[a b]>
      ], _, -> it.should.match /403/; done!
      it.should.eq null
    .. 'allowed with secret key', (done) ->
      <- skip_unless_pg93 plx, done
      res <- plx.insert collection: \pgrest_protected, pgparam: {auth: \secret}, $: [
        * field: \a, value: <[a b]>
      ]
      res.should.be.deep.eq [1]
      res <- plx.upsert collection: \pgrest_protected, pgparam: {auth: \wrong}, q: {field: \a}, $: $set:
        value: <[c d]>
      , _, -> it.should.match /403/; done!
      console.log "not supposed to be here"
      res.should.be.null!
