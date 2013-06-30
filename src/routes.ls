require! trycatch
export function route (path, fn)
  (req, resp) ->
    # TODO: Content-Negotiate into CSV
    return resp.send 200 if req.method is \OPTION
    resp.setHeader \Content-Type 'application/json; charset=UTF-8'
    done = -> switch typeof it
      | \number => resp.send it it
      | \object => resp.send 200 JSON.stringify it
      | \string => resp.send "#it"
    handle-error = -> it.=message if it instanceof Error; switch typeof it
      | \number => resp.send it, { error: it }
      | \object => resp.send 500 it
      | \string => (if it is /^\d\d\d$/
        then resp.send it, { error: it }
        else resp.send 500 { error: "#it" })
      | _       => resp.send 500 { error: "#it" }
    trycatch do
      -> fn.call req, ->
        if it.error
          handle-error that
        else
          done it
      handle-error

export function derive-type (content, type)
  TypeMap = Boolean: \boolean, Number: \numeric, String: \text, Array: 'text[]', Object: \plv8x.json
  TypeMap[typeof! content || \plv8x.json]

export function mount-model (plx, schema, name, _route=route)
  _route "#name" !->
    param = @query{ l, sk, c, s, q, fo, f, u, delay } <<< collection: "#schema.#name"
    method = switch @method
    | \GET    => \select
    | \POST   => \insert
    | \PUT    => (if param.u then \upsert else \replace)
    | \DELETE => \remove
    | _       => throw 405
    param.$ = @body # TODO: Accept CSV as PUT/POST Content-Type
    # text/csv;header=present
    # text/csv;header=absent
    plx[method].call plx, param, it, (error) ->
      if error is /Stream unexpectedly ended/
        console.log \TODOreconnect
      it { error }
  _route "#name/:_id" !->
    param = l: 1 fo: yes collection: "#schema.#name" q: { _id: @params._id }
    method = switch @method
    | \GET    => \select
    | \PUT    => \upsert
    | \DELETE => \remove
    | _       => throw 405
    param.$ = @body
    plx[method].call plx, param, it, (error) -> it { error }
  return name

export function mount-default (plx, schema, _route=route, cb)
  schema-cond = if schema
      "IN ('#{schema}')"
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
      mount-model plx, scm, tbl, _route
  default-schema ?= \public

  _route null, -> it <[ collections runCommand ]>
  _route "", !(done) -> done cols
  _route ":name", !(done) ->
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
    do-insert = ~>
      mount-model plx, schema, name, _route
      plx.insert param, done, (error) -> done { error }
    if @method is \POST
      plx.query """
        CREATE TABLE "#name" (#{
          [ "\"#col\" #typ" for col, typ of cols ] * ",\n"
        })
      """ do-insert
    else
      do-insert!

  _route '/runCommand' -> throw "Not implemented yet"

  cb cols
