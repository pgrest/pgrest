should = (require \chai).should!

export function provide-dbcfg()
  throw "environment variable TESTDBNAME is required" unless process.env.TESTDBNAME
  obj = {dbuser: process.env.TESTDBUSERNAME, dbname: process.env.TESTDBNAME}

export function provide-dbconn()
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
