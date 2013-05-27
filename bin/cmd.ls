``#!/usr/bin/env node``
require! {optimist, plv8x}
{argv} = optimist
conString = argv.db or process.env['PLV8XCONN'] or process.env['PLV8XDB'] or process.env.TESTDBNAME or process.argv?2
unless conString
  console.log "ERROR: Please set the PLV8XDB environment variable, or pass in a connection string as an argument"
  process.exit!
{pgsock} = argv

if pgsock
  conString = do
    host: pgsock
    database: conString

plx <- require \.. .new conString, {}
pgrest = (require \../lib/pgrest)

process.exit 0 if argv.boot
{port=3000, prefix="/collections", host="127.0.0.1"} = argv
express = try require \express
throw "express required for starting server" unless express
app = express!
require! cors
require! gzippo
require! \connect-csv

app.use gzippo.compress!
app.use express.json!
app.use connect-csv header: \guess

route = (path, fn) ->
  fullpath = "#{
      switch path.0
      | void => prefix
      | '/'  => ''
      | _    => "#prefix/"
    }#path"
  app.all fullpath, cors!, pgrest.route path, fn

schema-cond = if argv.schema
    "IN ('#{argv.schema}')"
else
    "NOT IN ( 'information_schema', 'pg_catalog', 'plv8x')"

# Generic JSON routing helper

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
  $ = if Array.isArray @body then @body else [@body]
  param = { $, collection: "#default-schema.#name" }
  cols = {}
  if Array.isArray $.0
    [insert-cols, ...entries] = $
    for row in entries
      for key, idx in insert-cols | row[idx]?
        cols[key] = derive-type row[idx], cols[key]
  else for row in $
    for key in Object.keys row | row[key]?
      cols[key] = derive-type row[key], cols[key]
  <- plx.query """
    CREATE TABLE "#name" (#{
      [ "#col #typ" for col, typ of cols ] * ",\n"
    })
  """
  mount-model schema, name
  plx.insert param, done, -> throw "#it"

route '/runCommand' -> throw "Not implemented yet"

app.listen port, host
console.log "Available collections:\n#{ cols * ' ' }"
console.log "Serving `#conString` on http://#host:#port#prefix"

function derive-type (content, type)
  TypeMap = Boolean: \boolean, Number: \numeric, String: \text, Array: 'text[]', Object: \plv8x.json
  TypeMap[typeof! content || \plv8x.json]

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
