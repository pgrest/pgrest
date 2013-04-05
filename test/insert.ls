should = (require \chai).should!

expect = (require \chai).expect
var pgrest, plx, conString
describe 'pgrest', -> ``it``
  .. 'loaded successfully.', (done) ->
    # Load home page
    conString := "tcp://localhost/#{ process.env.TESTDBNAME }"
    pgrest := require \..
    pgrest.should.be.ok
    _plx <- pgrest.new conString, {}
    plx := _plx
    done!
#  .. 'error', (done) ->
#    (-> plx.query "X" -> console.error \grr).should.throw 'syntax error at or near "X"'
#    done!
  .. 'test data', (done) ->
    res <- plx.query """
    DROP TABLE IF EXISTS pgrest_test;
    CREATE TABLE pgrest_test (
        field text not null primary key,
        value text not null,
        last_update timestamp
    );
    INSERT INTO pgrest_test (field, value, last_update) values('pgrest_version', '0.0.1', NOW());
    """
    done!
  .. 'insert objects', (done) ->
    [pgrest_insert:res] <- plx.query """select pgrest_insert($1)""", [JSON.stringify collection: \pgrest_test, $: [
      * field: \zz, value: \z1
      * field: \z3, value: \z2
    ] ]
    res = JSON.parse res
    expect res .to.deep.equal [1,1]
    [pgrest_select:res] <- plx.query """select pgrest_select($1)""", [JSON.stringify collection: \pgrest_test]
    res = JSON.parse res
    expect res.paging.count .to.equal 3
    done!
  .. 'insert array', (done) ->
    [pgrest_insert:res] <- plx.query """select pgrest_insert($1)""", [JSON.stringify collection: \pgrest_test, $: [
      <[field value]>
      <[ z4 v4 ]>
      <[ z5 v5 ]>
    ] ]
    res = JSON.parse res
    expect res .to.deep.equal [1,1]
    [pgrest_select:res] <- plx.query """select pgrest_select($1)""", [JSON.stringify collection: \pgrest_test]
    res = JSON.parse res
    expect res.paging.count .to.equal 5
    done!
