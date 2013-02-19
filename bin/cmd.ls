``#!/usr/bin/env node``
require! {optimist, plv8x}
{argv} = optimist
conString = argv.db or process.env.PGRESTCONN or process.env.TESTDBNAME

plx <- (require \../).new conString

process.exit 0 if argv.boot
port = argv.port ? 3000
express = try require \express 
throw "express required for starting server" unless express
app = express!

rows <- plx.query """
  SELECT t.table_name tbl FROM INFORMATION_SCHEMA.TABLES t WHERE t.table_schema NOT IN (
    'information_schema', 'pg_catalog', 'plv8x'
  );
"""
cols = for {tbl} in rows => mount-model tbl

app.get '/collections', (req, res) ->
  res.setHeader 'Content-Type', 'application/json; charset=UTF-8'
  res.end JSON.stringify cols

app.listen port
console.log "Available collections:\n#{ cols * ' ' }"
console.log "Serving `#conString` on http://localhost:#port/collections"

function mount-model (name)
  app.get "/collections/#name", (req, resp) ->
    param = req.query{ l, sk, c, s, q } <<< { collection: name }
    try
      body <- plx.select param
      resp.setHeader 'Content-Type' 'application/json; charset=UTF-8'
      resp.end body
    catch
      return resp.end "error: #e"
  return name
