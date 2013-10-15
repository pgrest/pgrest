should = (require \chai).should!
expect = (require \chai).expect
{mk-pgrest-fortest} = require \./testlib

var plx, _plx
describe 'JSON', ->
  this.timeout 10000ms
  beforeEach (done) ->
    _plx <- mk-pgrest-fortest!
    plx := _plx
    <- plx.query """
    DROP TABLE IF EXISTS pgrest_test;
    CREATE TABLE pgrest_test (
        field text not null primary key,
        value plv8x.json not null,
        last_update timestamp
    );
    """
    done!
  afterEach (done) ->
    <- plx.query """DROP TABLE IF EXISTS pgrest_test;"""
    done!
  describe.skip 'insert objects', -> ``it``
    .. 'should return true if operation is success', (done) ->
      [pgrest_insert:res] <- plx.query """select pgrest_insert($1)""", [collection: \pgrest_test, $: [
        * field: \jsonobject, value: type: \object
        * field: \jsonarray, value: <[am array]>
      ] ]
      expect res .to.deep.equal [1,1]
      [pgrest_select:res] <- plx.query """select pgrest_select($1)""", [collection: \pgrest_test]
      console.log res
      expect res.paging.count .to.equal 2
      content = {[field, value] for {field,value} in res.entries}
      expect content.jsonarray .to.deep.equal <[am array]>
      done!
  describe 'insert array', -> ``it``
    .. 'should return true if operation is success', (done) ->
      [pgrest_insert:res] <- plx.query """select pgrest_insert($1)""", [collection: \pgrest_test, $: [
        <[field value]>
        [\jsonobject, type: \object]
        [\jsonarray, <[am array]>]
      ] ]
      expect res .to.deep.equal [1,1]
      [pgrest_select:res] <- plx.query """select pgrest_select($1)""", [collection: \pgrest_test]
      expect res.paging.count .to.equal 2
      done!
