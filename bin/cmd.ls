``#!/usr/bin/env node``
require! {optimist, plv8x}
{argv} = optimist
conString = argv.db or process.env.PGRESTCONN or process.env.TESTDBNAME or process.argv?2

plx <- (require \../).new conString

process.exit 0 if argv.boot
{port=3000, prefix="/collections"} = argv
express = try require \express 
throw "express required for starting server" unless express
app = express!
require! cors
require! gzippo

app.use gzippo.compress!
app.use express.json!

schema-cond = if argv.schema
    "IN ('#{argv.schema}')"
else
    "NOT IN ( 'information_schema', 'pg_catalog', 'plv8x')"


rows <- plx.query """
  SELECT t.table_schema, t.table_name tbl FROM INFORMATION_SCHEMA.TABLES t WHERE t.table_schema #schema-cond;
"""
seen = {}
cols = for {table_schema, tbl} in rows
  if seen[tbl]
    console.log "#table_schema.#tbl not loaded, #tbl already in use"
  else
    seen[tbl] = true
    mount-model table_schema, tbl

app.all prefix, cors!, (req, res) ->
  res.setHeader 'Content-Type', 'application/json; charset=UTF-8'
  res.end JSON.stringify cols

app.listen port
console.log "Available collections:\n#{ cols * ' ' }"
console.log "Serving `#conString` on http://localhost:#port#prefix"

function mount-model (schema, name)
  app.all "#prefix/#name", cors!, (req, resp) ->
    resp.setHeader 'Content-Type' 'application/json; charset=UTF-8'
    param = req.query{ l, sk, c, s, q, fo, u, delay } <<< { collection: "#schema.#name" }
    method = switch req.method
    | \GET    => \select
    | \POST   => \insert
    | \PUT    => (if param.u then \upsert else \replace)
    | \DELETE => \remove
    param.$ = req.body
    body <- plx[method].call plx, param, _, -> resp.end JSON.stringify { error: "#it" }
    resp.end body
  app.all "#prefix/#name/:_id", cors!, (req, resp) ->
    resp.setHeader 'Content-Type' 'application/json; charset=UTF-8'
    param = { l: 1 fo: yes collection: "#schema.#name" q: { _id: req.params._id } }
    method = switch req.method
    | \GET    => \select
    | \PUT    => \upsert
    | \DELETE => \remove
    param.$ = req.body
    body <- plx[method].call plx, param, _, -> resp.end JSON.stringify { error: "#it" }
    resp.end body
  return name
