should = (require \chai).should!

expect = (require \chai).expect
var pgrest, plx, conString
describe 'pgrest', -> ``it``
  .. 'loaded successfully.', (done) ->
    # Load home page
    conString := "tcp://localhost/#{ process.env.TESTDBNAME }"
    pgrest := require \..
    pgrest.should.be.ok
    _plx <- pgrest.new conString
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
  .. 'udpate', (done) ->
    [pgrest_upsert:res] <- plx.query """select pgrest_upsert($1)""", [JSON.stringify collection: \pgrest_test, $set: {value: \0.0.2}, q: {field: \pgrest_version} ]
    res = JSON.parse res
    expect res.updated .to.equal true
    [pgrest_select:res] <- plx.query """select pgrest_select($1)""", [JSON.stringify collection: \pgrest_test]
    res = JSON.parse res
    expect res.paging.count .to.equal 1
    done!
  .. 'insert', (done) ->
    [pgrest_upsert:res] <- plx.query """select pgrest_upsert($1)""", [JSON.stringify collection: \pgrest_test, $set: {value: \test}, q: {field: \pgrest_deployment} ]
    res = JSON.parse res
    expect res.inserted .to.equal true
    [pgrest_select:res] <- plx.query """select pgrest_select($1)""", [JSON.stringify collection: \pgrest_test]
    res = JSON.parse res
    expect res.paging.count .to.equal 2
    done!
  .. 'contention', (done) ->
    require! plv8x
    conn = plv8x.connect conString
    <- conn.query 'select plv8x.boot()'
    <- plv8x.plv8x-eval conn, -> plv8x_require \pgrest .boot!
    plx.query """select pgrest_upsert($1)""", [JSON.stringify collection: \pgrest_test, $set: {value: \yes}, delay: 1, q: {field: \pgrest_haslock} ], (delayed) ->
        [pgrest_select:res] <- plx.query """select pgrest_select($1)""", [JSON.stringify collection: \pgrest_test]
        res = JSON.parse res
        expect res.paging.count .to.equal 3
        expect [value for {field, value} in res.entries | field is \pgrest_haslock].0 .to.equal \yes
        done!
    res <- conn.query """select pgrest_upsert($1)""", [JSON.stringify collection: \pgrest_test, $set: {value: \no}, q: {field: \pgrest_haslock} ]
    console.log res
