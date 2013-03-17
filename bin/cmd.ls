``#!/usr/bin/env node``
require! {optimist, plv8x, trycatch}
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

# Generic JSON routing helper
route = (path, fn) -> app.all "#prefix#path", cors!, (req, resp) ->
  resp.setHeader \Content-Type 'application/json; charset=UTF-8'
  done = -> switch typeof it
    | \number => resp.send it it
    | \object => resp.send 200 JSON.stringify it
    | \string => resp.send "#it"
  trycatch do
    -> done fn.call req, -> done it
    -> it.=message if it instanceof Error; switch typeof it
    | \number => resp.send it, { error: it }
    | \object => resp.send 500 it
    | \string => (if it is /^\d\d\d$/
      then resp.send it, { error: it }
      else resp.send 500 { error: "#it" })
    | _       => resp.send 500 { error: "#it" }

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

route "" -> cols
route "/:name" ->
  # Non-existing collection
  console.log @method
  throw 404 if @method in <[ GET DELETE ]>
  return []

app.listen port
console.log "Available collections:\n#{ cols * ' ' }"
console.log "Serving `#conString` on http://localhost:#port#prefix"

function mount-model (schema, name)
  route "/#name" !->
    param = @query{ l, sk, c, s, q, fo, u, delay } <<< collection: "#schema.#name"
    method = switch @method
    | \GET    => \select
    | \POST   => \insert
    | \PUT    => (if param.u then \upsert else \replace)
    | \DELETE => \remove
    param.$ = @body
    plx[method].call plx, param, it, -> throw "#it"
  route "/#name/:_id" !->
    param = l: 1 fo: yes collection: "#schema.#name" q: { _id: @params._id }
    method = switch @method
    | \GET    => \select
    | \PUT    => \upsert
    | \DELETE => \remove
    param.$ = @body
    plx[method].call plx, param, it, -> throw "#it"
  return name
