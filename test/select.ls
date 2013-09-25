should = (require \chai).should!
{mk-pgrest-fortest} = require \./testlib

var _plx, plx
describe 'Select', ->
  this.timeout 10000ms
  beforeEach (done) ->
    _plx <- mk-pgrest-fortest!
    plx := _plx
    #@XXXX need to remove pgrest_boot
    <- plx.query """
    DROP TABLE IF EXISTS pgrest_test;
    CREATE TABLE pgrest_test (
        field text not null primary key,
        value text[] not null,
        last_update timestamp
    );
    INSERT INTO pgrest_test (field, value, last_update) values('a', '{0.0.1}', NOW());
    INSERT INTO pgrest_test (field, value, last_update) values('b', '{0.0.2}', NOW());
    INSERT INTO pgrest_test (field, value, last_update) values('c', '{0.0.3}', NOW());
    INSERT INTO pgrest_test (field, value, last_update) values('d', '{0.0.4}', NOW());
    INSERT INTO pgrest_test (field, value, last_update) values('e', '{0.0.4}', NOW());
    select pgrest_boot('{}');
    """
    done!
  afterEach (done) ->
    <- plx.query "DROP TABLE IF EXISTS pgrest_test;"
    done!
  describe 'is excepted to return a self-descriptive result', -> ``it``
    .. 'should contain operation name, paging info.', (done) ->
      res <- plx.query """select pgrest_select($1)""", [collection: \pgrest_test]
      res.0.should.have.keys 'pgrest_select'
      res.0.pgrest_select.paging.count.should.eql 5
      res.0.pgrest_select.paging.l.should.eql 30
      res.0.pgrest_select.paging.sk.should.eql 0
      done!
  describe 'table/view(s) with other conditoin', -> ``it``
    .. 'should restrict results by the specified JSON query.', (done) ->
      q = [collection: \pgrest_test, q: {field:'a'}]
      [pgrest_select:res] <- plx.query """select pgrest_select($1)""", q
      res.paging.count.should.eq 1
      res.entries.0.field.should.eq 'a'
      res.entries.0.value.0.should.eq '0.0.1'

      q = [collection: \pgrest_test, q: {value:'{0.0.4}'}]
      [pgrest_select:res] <- plx.query """select pgrest_select($1)""", q
      res.paging.count.should.eq 2
      done!
    .. 'should only return the result count for this query if c is given.', (done) ->
      [pgrest_select:res] <- plx.query """select pgrest_select($1)""", [collection: \pgrest_test, c:true]
      res.count.should.eq 5
      done!
    .. 'should return a single document from the result set if fo is given', (done) ->
      q = [collection: \pgrest_test, fo: true, q: {field:'a'}]
      [pgrest_select:res] <- plx.query """select pgrest_select($1)""", q
      res.field.should.eq 'a'
      res.value.0.should.eq '0.0.1'
      done!
    .. 'should return result which does not has element that the column name is specified to exclude.. ', (done) ->
      q = [collection: \pgrest_test, f: {field: -1}]
      [pgrest_select:res] <- plx.query """select pgrest_select($1)""", q
      res.entries.map ->
        it.field? .should.not.ok
      done!
    .. 'should return result which only has elements that the column name is specified to include.', (done) ->
      q = [collection: \pgrest_test, f: {field: 1, value: 1}]
      [pgrest_select:res] <- plx.query """select pgrest_select($1)""", q
      res.entries.map ->
        it.field? .should.ok
        it.value? .should.ok
        it.last_update? .should.not.ok
        [k for k,v of it] .length .should.eq 2
      done!      
    .. 'should return limited subset when paging is given in the condition.', (done) ->
      [pgrest_select:res] <- plx.query """select pgrest_select($1)""", [collection: \pgrest_test, l:'1']
      res.paging.count.should.eq 5
      res.paging.l.should.eq 1
      res.paging.sk.should.eq 0
      done!
    .. 'should skip N elements if sk is given ', (done) ->
      [0 to 5].map ->
        [pgrest_select:res] <- plx.query """select pgrest_select($1)""", [collection: \pgrest_test, sk:it]
        res.entries.length.should.eq (5-it)        
      done!
    .. .skip 'should raise error if sk or l is out of range.', (done) ->
      [pgrest_select:res] <- plx.query """select pgrest_select($1)""", [collection: \pgrest_test, sk: 5, l:6]
      #@FIXME: non of either error message notice an user his sk or l argument is invalid.
      done!