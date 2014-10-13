should = (require \chai).should!

export function provide-dbcfg()
  throw "environment variable TESTDBNAME is required" unless process.env.TESTDBNAME
  obj = {dbuser: process.env.TESTDBUSERNAME, dbname: process.env.TESTDBNAME}

export function provide-dbconn()
  return that if process.env.TESTDB
  cfg = provide-dbcfg!
  prefix = if cfg.dbuser
    then "#{cfg.dbuser}@"
    else ''
  "tcp://#{prefix}localhost/#{cfg.dbname}"

export function mk-pgrest-fortest(opts, cb)
  if \function is typeof opts
    cb = opts
    opts = {}
  pgrest = require \..
  pgrest.should.be.ok
  pgrest.new provide-dbconn!, opts, cb

export function create-test-table(plx, cb)
  <- plx.query """
  DROP TABLE IF EXISTS pgrest_test cascade;
  CREATE TABLE pgrest_test (
      field text not null primary key,
      value text[] not null,
      last_update timestamp
  );
  """
  cb!

export function cleanup-test-table(plx, cb)
  <- plx.query """
  DROP TABLE IF EXISTS pgrest_test cascade;
  """
  cb!
