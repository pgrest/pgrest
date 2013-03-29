``#!/usr/bin/env node``
require! {optimist, plv8x, trycatch}
{argv} = optimist
conString = argv.db or process.env.PGRESTCONN or process.env.TESTDBNAME or process.argv?2
{pgsock} = argv

if pgsock
  conString = do
    host: pgsock
    database: conString

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
route = (path, fn) -> app.all "#{
  switch path.0
  | void => prefix
  | '/'  => ''
  | _    => "#prefix/"
}#path", cors!, (req, resp) ->
  # TODO: Content-Negotiate into CSV
  return resp.send 200 if req.method is \OPTION
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
  SELECT t.table_schema scm, t.table_name tbl FROM INFORMATION_SCHEMA.TABLES t WHERE t.table_schema #schema-cond;
"""
seen = {}
default-schema = null
cols = for {scm, tbl} in rows
  schema ||= scm
  if seen[tbl]
    console.log "#scm.#tbl not loaded, #tbl already in use"
  else
    seen[tbl] = true
    mount-model scm, tbl
default-schema ?= \public

route "" -> cols
route ":name", !(done) ->
  throw 404 if @method in <[ GET DELETE ]> # TODO: If not exist, remount
  throw 405 if @method not in <[ POST PUT ]>
  { name } = @params
  # Non-existing collection - Autovivify it
  # Strategy: Enumerate all unique columns & data types, and CREATE TABLE accordingly.
  param = collection: "#default-schema.#name" $: if Array.isArray @body then @body else [@body]
  cols = {}
  TypeMap = boolean: \boolean, number: \numeric, string: \text, object: \plv8x.json
  for row in param.$
    for key in Object.keys row | row[key]?
      cols[key] ||= (TypeMap[typeof row[key]] || \plv8x.json)
  <- plx.query """
    CREATE TABLE "#name" (#{
      [ "#col #typ" for col, typ of cols ] * ",\n"
    })
  """
  mount-model schema, name
  plx.insert param, done, -> throw "#it"

route '/runCommand' -> throw "Not implemented yet"

app.listen port
console.log "Available collections:\n#{ cols * ' ' }"
console.log "Serving `#conString` on http://localhost:#port#prefix"

function mount-model (schema, name)
  route "#name" !->
    param = @query{ l, sk, c, s, q, fo, u, delay } <<< collection: "#schema.#name"
    method = switch @method
    | \GET    => \select
    | \POST   => \insert
    | \PUT    => (if param.u then \upsert else \replace)
    | \DELETE => \remove
    | _       => throw 405
    param.$ = @body # TODO: Accept CSV as PUT/POST Content-Type
    # text/csv;header=present
    # text/csv;header=absent
    plx[method].call plx, param, it, -> throw "#it"
  route "#name/:_id" !->
    param = l: 1 fo: yes collection: "#schema.#name" q: { _id: @params._id }
    method = switch @method
    | \GET    => \select
    | \PUT    => \upsert
    | \DELETE => \remove
    | _       => throw 405
    param.$ = @body
    plx[method].call plx, param, it, -> throw "#it"
  return name
