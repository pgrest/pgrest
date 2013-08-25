should = (require \chai).should!
expect = (require \chai).expect
mk-pgrest-fortest = (require \./testlib).mk-pgrest-fortest
provide-dbconn = (require \./testlib).provide-dbconn

var _plx, plx
describe 'Upsert', ->
  beforeEach (done) ->
    _plx <- mk-pgrest-fortest!
    plx := _plx
    <- plx.query """
    CREATE TABLE pgrest_test (
        field text not null primary key,
        value text not null,
        last_update timestamp
    );
    INSERT INTO pgrest_test (field, value, last_update) values('pgrest_version', '0.0.1', NOW());    
    """    
    done!
  afterEach (done) ->
    <- plx.query "DROP TABLE IF EXISTS pgrest_test;"
    done!
  describe 'a existen entity', -> ``it``    
    .. 'should perform update operation.', (done) ->
      [pgrest_upsert:res] <- plx.query """select pgrest_upsert($1)""", [collection: \pgrest_test, $: { $set: {value: \0.0.2} }, q: {field: \pgrest_version} ]
      res.updated.should.be.ok
      [pgrest_select:res] <- plx.query """select pgrest_select($1)""", [collection: \pgrest_test]
      res.paging.count.should.equal 1
      done!
  describe 'a non-existen entity', -> ``it``    
    .. 'should perform insert operation.', (done) ->      
      [pgrest_upsert:res] <- plx.query """select pgrest_upsert($1)""", [collection: \pgrest_test, $: { $set: {value: \test} }, q: {field: \pgrest_deployment} ]
      res.inserted.should.be.ok
      [pgrest_select:res] <- plx.query """select pgrest_select($1)""", [collection: \pgrest_test]
      res.paging.count.should.equal 2
      done!
  describe 'in contention', -> ``it``    
    .. '@FIXME: add test pupose here.', (done) ->      
      require! plv8x
      conn = plv8x.connect provide-dbconn!
      <- conn.query 'select plv8x.boot()'
      <- plv8x.plv8x-eval conn, -> plv8x_require \pgrest .boot!
      plx.query """select pgrest_upsert($1)""", [collection: \pgrest_test, $: { $set: {value: \yes} }, delay: 1, q: {field: \pgrest_haslock} ], (delayed) ->
        [pgrest_select:res] <- plx.query """select pgrest_select($1)""", [collection: \pgrest_test]
        expect res.paging.count .to.equal 2
        expect [value for {field, value} in res.entries | field is \pgrest_haslock].0 .to.equal \yes
        done!
      res <- conn.query """select pgrest_upsert($1)""", [collection: \pgrest_test, $: { $set: {value: \no} }, q: {field: \pgrest_haslock} ]
      console.log res
