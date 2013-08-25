should = (require \chai).should!
mk-pgrest-fortest = (require \./testlib).mk-pgrest-fortest

var _plx, plx
describe 'Insert', ->
  beforeEach (done) ->
    _plx <- mk-pgrest-fortest!
    plx := _plx
    <- plx.query """
    DROP TABLE IF EXISTS pgrest_test;
    CREATE TABLE pgrest_test (
        field text not null primary key,
        value text not null,
        last_update timestamp
    );
    """    
    done!
  describe 'is excepted to return a self-descriptive result', -> ``it``    
    .. 'should contatin the operation name in the result.', (done) ->
      res <- plx.query """select pgrest_insert($1)""", [collection: \pgrest_test, $: [field:1, value:2]]
      res.0.should.have.keys 'pgrest_insert'
      done!      
  describe 'objects', -> ``it``
    .. 'should return true if operation is success', (done) ->
      [pgrest_insert:res] <- plx.query """select pgrest_insert($1)""", [collection: \pgrest_test, $: [
        * field: \zz, value: \z1
        * field: \z3, value: \z2
      ] ]
      res.should.deep.equal [1,1]
      done!
  describe 'array', -> ``it``
    .. 'should return true if operation is success', (done) ->
      [pgrest_insert:res] <- plx.query """select pgrest_insert($1)""", [collection: \pgrest_test, $: [
      <[field value]>
        <[ z4 v4 ]>
        <[ z5 v5 ]>
      ] ]
      res.should.deep.equal [1,1]
      [pgrest_select:res] <- plx.query """select pgrest_select($1)""", [collection: \pgrest_test]
      res.paging.count.should.equal 2
      done!