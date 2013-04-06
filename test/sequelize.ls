should = (require \chai).should!

expect = (require \chai).expect
var pgrest, plx
describe 'db', -> ``it``
  .. 'loaded successfully.', (done) ->
    # Load home page
    conString = "tcp://localhost/#{ process.env.TESTDBNAME }"
    console.log conString
    pgrest := require \..
    pgrest.should.be.ok
    _plx <- pgrest.new conString, {}
    plx := _plx
    plx.should.be.ok
    done!
  .. 'purge', (done) ->
    <- plx.purge
    done!
  .. 'import', (done) ->
    <- plx.import-bundle \sequelize, './node_modules/sequelize/package.json'
    <- plx.import-bundle \pgrest, './package.json'
    done!
  .. 'test data', (done) ->
    err, res <- plx.conn.query """
    DROP TABLE IF EXISTS pgrest_test;
    CREATE TABLE pgrest_test (
        field text not null,
        value text not null,
        last_update timestamp
    );
    INSERT INTO pgrest_test (field, value, last_update) values('pgrest_version', '0.0.1', NOW());
    """
    expect(err).to.be.a('null');
    done!
  .. 'sequelize test', (done) ->
    compiled <- plx.ap (-> plv8x.require("LiveScript").compile), ["""
    plv8x_require "pgrest" .boot!
    {STRING, TEXT, DATE, BOOLEAN, INTEGER}:Sequelize = plv8x_require "sequelize"
    sql = new Sequelize null, null, null { dialect: "plv8", -logging }

    SystemModel = do
        field: { type: STRING, +primaryKey }
        value: STRING
        last_update: DATE

    System = sql.define 'pgrest_test' SystemModel, { +freezeTableName }

    rv = null
    do
        (entry) <- System.find('pgrest_version').on "success"
        rv := entry

    pgprocess.next!

    JSON.stringify rv
    """, {+bare}]
    ret <- plx.eval JSON.parse compiled
    expect ret?field .to.equal "pgrest_version"
    expect ret?value .to.equal "0.0.1"
    done!
