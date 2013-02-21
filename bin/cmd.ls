``#!/usr/bin/env node``
require! {optimist, plv8x}
{argv} = optimist
conString = argv.db or process.env.PGRESTCONN or process.env.TESTDBNAME or process.argv?2

plx <- (require \../).new conString

process.exit 0 if argv.boot
port = argv.port ? 3000
express = try require \express 
throw "express required for starting server" unless express
app = express!
require! cors

rows <- plx.query """
  SELECT t.table_name tbl FROM INFORMATION_SCHEMA.TABLES t WHERE t.table_schema NOT IN (
    'information_schema', 'pg_catalog', 'plv8x'
  );
"""
cols = for {tbl} in rows => mount-model tbl

app.all '/collections', cors!, (req, res) ->
  res.setHeader 'Content-Type', 'application/json; charset=UTF-8'
  res.end JSON.stringify cols

app.listen port
console.log "Available collections:\n#{ cols * ' ' }"
console.log "Serving `#conString` on http://localhost:#port/collections"

function mount-model (name)
  app.all "/collections/#name", cors!, (req, resp) ->
    param = req.query{ l, sk, c, s, q, fo } <<< { collection: name }
    resp.setHeader 'Content-Type' 'application/json; charset=UTF-8'
    body <- plx.select param, _, -> resp.end JSON.stringify { error: "#it" }
    resp.end body
  return name
