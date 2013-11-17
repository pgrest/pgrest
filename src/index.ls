require! plv8x
exports.new = (conString, config, cb) ->
  throw "Expected: new(dsn, cb) where dsn is 'db', 'host/db' or 'tcp://host/db'" unless conString
  if typeof conString is \string
    conString = "localhost/#conString" unless conString is // / //
    conString = "tcp://#conString"     unless conString is // :/ //
  plx <- plv8x.new conString
  do-import = (cb) ->
    next <- plx.import-bundle-funcs \pgrest require.resolve(\../package.json)
    <- next!
    cb!
  plx.config = config
  if config.client
    do-import = (cb) -> cb!
  <- do-import
  plx.boot = (cb) -> plx.ap (-> plv8x.require \pgrest .boot), [config], cb
  plx.conn.on \error ->
    console.log \pgerror it
    throw it
  <- plx.boot
  <[ select upsert insert replace remove ]>.forEach (method) ->
    plx[method] = (param, cb, onError) ->
      err, {rows}? <- @conn.query "select pgrest_#method($1) as ret" [param]
      return onError?(err) if err
      ret = rows.0.ret
      cb? ret
  return cb plx if cb
  return plx.conn.end!

{q,qq,compile,build_view_source,order-by} = require \./sql

export routes = -> require \./routes
export get-opts = -> require \./cli .get-opts
export cli = -> require \./cli .cli
export socket = -> require \./socket

function with-pgparam(fn)
  (param) ->
    if param.pgparam
      pgrest_param_setobj delete param.pgparam
    fn param

export pgrest_select = with-pgparam (param) ->
    for p in <[l sk c]> | typeof param[p] is \string => param[p] = parseInt param[p]
    for p in <[q s f]>  | typeof param[p] is \string => param[p] = JSON.parse param[p]
    {collection, l = 30, sk = 0, q, c, s, f, fo} = param
    meta = pgrest.config?meta?[collection]
    # XXX: experimental defaults import from meta
    fo ?= meta?fo
    f ?= meta?f
    s ?= meta?s
    id-column = pgrest.PrimaryFieldOf[meta?as ? collection]
    q[id-column] = delete q._id if q?_id and id-column
    cond = compile collection, q if q

    if (collection / '.').length == 1
      collection = "public.#{collection}"

    if pgrest.ColumnsOf[collection]
      columns = [].concat that
      if f
        inclusive = 1 in for name, v of f
          throw 404 unless name in columns
          +v
        if inclusive
          columns.=filter (f.)
        else
          columns.=filter -> !f[it]? or f[it] == 1
    else
      columns = ['*']

    columns.push id-column if id-column
    query = "SELECT #{columns.map qq .join ", "} FROM #{ qq collection }"

    query += " WHERE #cond" if cond?
    [{count}] = plv8.execute "select count(*) from (#query) cnt"
    throw 404 if fo and count is 0
    return { count } if c

    query += " ORDER BY " + order-by s if s
    limit = if l is -1 => "" else "limit #l"
    # XXX: document _ special case
    maybe_ = ->
      while it?_?
        it.=_
        it = JSON.parse it if \string is typeof it
      return it
    return maybe_ (plv8.execute "#query #limit offset $1" [sk])?0 if fo
    do
        paging: { count, l, sk }
        entries: plv8.execute "#query #limit offset $1" [sk] .map maybe_
        query: cond
pgrest_select.$plv8x = '(plv8x.json):plv8x.json'

export pgrest_remove = with-pgparam (param) ->
  for p in <[q]> | typeof param[p] is \string => param[p] = JSON.parse param[p]
  {collection, $, q} = param
  cond = compile collection, q if q
  query = "DELETE FROM #{ qq collection }"
  query += " WHERE #cond" if cond?
  return plv8.execute query
pgrest_remove.$plv8x = '(plv8x.json):plv8x.json'

export pgrest_replace = with-pgparam (param) ->
  pgrest_remove param
  return pgrest_insert param
pgrest_replace.$plv8x = '(plv8x.json):plv8x.json'

function refresh-meta(collection)
  pgrest.Meta ?= {}
  [schema, table] = collection.split \.
  unless table
    [schema, table] = [\public, schema]
  pgrest.Meta[collection] = {[column_name, data_type] for {column_name, data_type} in plv8.execute """
  select column_name, data_type from information_schema.columns where table_schema = $1 and table_name = $2
  """, [schema, table]}

function _insert_statement(collection, insert-cols, insert-vals)
  meta = pgrest.Meta[collection]
  values = ["$#{i+1}" for _,i in insert-cols]
  todrop = []
  insert-vals = for v,i in insert-vals
    if !meta[insert-cols[i]]?
      console.warn "#{insert-cols[i]} not found, skipping"
      todrop.push i
      continue
    if meta[insert-cols[i]] is \ARRAY
      v
    else if v? and typeof v is \object
      JSON.stringify v
    else
      v
  for i in todrop.reverse!
    insert-cols.splice i, 1
    values.pop!
  ["INSERT INTO #{ qq collection }(#{insert-cols.map qq .join \,}) VALUES (#{values.join \,})", insert-vals]

export pgrest_insert = with-pgparam (param) ->
  {collection, $} = param

  refresh-meta collection
  return if Array.isArray $ and Array.isArray $.0
    [insert-cols, ...entries] = $
    for $value in entries
      [query, insert-vals] = _insert_statement collection, insert-cols, $value
      plv8.execute query, insert-vals
  else
    for $set in (if Array.isArray $ then $ else if $ then [$] else [])
      insert-cols = [k for k of $set]
      continue unless insert-cols.length
      [query, insert-vals] = _insert_statement collection, insert-cols, [v for _, v of $set]
      plv8.execute query, insert-vals
pgrest_insert.$plv8x = '(plv8x.json):plv8x.json'

export pgrest_upsert = with-pgparam (param) ->
    for p in <[u delay]> | typeof param[p] is \string => param[p] = parseInt param[p]
    # XXX derive q from $set and table constraints
    for p in <[q]> | typeof param[p] is \string => param[p] = JSON.parse param[p]
    {collection, u, $={}, q, delay} = param
    {$set=$} = $

    # Updating _-only write-through views
    meta = refresh-meta collection
    $set = {_: $set} if meta?_ is /\bjson$/

    cond = compile collection, q if q
    cols = [k for k of $set]
    vals = for _,v of $set
      if \Object is typeof! v
        JSON.stringify v
      else
        v
    insert-cols = cols ++ [k for k of q]
    insert-vals = vals ++ [v for _, v of q]
    updates = ["#{qq it} = $#{i+1}" for it, i in cols]
    xi = 0
    while true
        query = "UPDATE #{ qq collection } SET #updates"
        query += " WHERE #cond" if cond?
        res = plv8.execute query, vals
        return {+updated} if res
        plv8.execute "select pg_sleep($1)" [delay] if delay
        [query, _vals] = _insert_statement collection, insert-cols, insert-vals
        res = try
          plv8.execute query, _vals
        catch e
          throw e unless e is /violates unique constraint/
        return {+inserted} if res

pgrest_upsert.$plv8x = '(plv8x.json):plv8x.json'

export function pgrest_param()
  plv8x.pgparam
pgrest_param.$plv8x = '():plv8x.json'

export function pgrest_param_get(key)
  plv8x.pgparam[key]
pgrest_param_get.$plv8x = '(text):text'

export function pgrest_param_set(key, value)
  plv8x.pgparam[key] = value
  plv8x.pgparam
pgrest_param_set.$plv8x = '(text,text):plv8x.json'

export function pgrest_param_setobj(pgparam)
  plv8x.pgparam = pgparam
pgrest_param_setobj.$plv8x = '(plv8x.json):plv8x.json'

export function boot(config)
    serial = 0
    deferred = []
    plv8x.pgparam = {}
    ``pgrest = {}``
    ``console`` = do
      log: -> plv8.elog(INFO, ...arguments)
      warn: -> plv8.elog(WARNING, ...arguments)
      error: -> plv8.elog(ERROR, ...arguments)
    ``setTimeout`` = (fn, ms=0) -> deferred.push [fn, ms + (serial++ * 0.001)]
    ``pgprocess`` = do
        nextTick: (fn) -> setTimeout fn
        next: ->
            doit = (-> return unless deferred.length; deferred.shift!0!; doit!)
            doit!
    PrimaryFieldOf = {}
    ColumnsOf = {}
    for {key, val, constraint} in plv8.execute SQL_PrimaryFieldInfo | val.length is 1
      # console.log "PrimaryFieldOf(#key) = #val (#constraint)"
      PrimaryFieldOf[key] = val.0
    for {name, columns} in plv8.execute SQL_ColumnsInfo
      ColumnsOf[name] = columns

    pgrest <<< { PrimaryFieldOf, ColumnsOf, config }
    return true

require! async
function build_rules(plx, cb)
  allrules = for relation, {rules} of plx.config.meta when rules
    for rule in rules => let {name, event, type, command} = rule
      (done) ->
        <- plx.query """
          CREATE OR REPLACE RULE #{name} AS ON #{event} TO #{relation}
            DO #{type} (#{command});
        """, (err) -> console.log err
        done!
  <- async.waterfall allrules.reduce (++)
  cb!

function build_views(plx, cb)
  views = for name, {as}:meta of plx.config.meta when as => let name
    source = build_view_source meta
    (done) ->
      <- plx.query """CREATE OR REPLACE view #name AS #source;""" -> console.log \err it
      done!
  err <- async.waterfall views
  cb!

export function bootstrap(plx, name, pkg, cb)
  next <- plx.import-bundle-funcs name, pkg
  <- build_views plx
  next -> build_rules plx, -> cb!

export pgrest_boot = boot
pgrest_boot.$plv8x = '(plv8x.json):boolean'
pgrest_boot.$bootstrap = true

const SQL_PrimaryFieldInfo = """
SELECT t.table_schema || '.' || t.table_name AS key,
       kcu.constraint_name AS constraint,
       array_agg('' || kcu.column_name) AS val
FROM INFORMATION_SCHEMA.TABLES t
   LEFT JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
        ON tc.table_catalog = t.table_catalog
       AND tc.table_schema = t.table_schema
       AND tc.table_name = t.table_name
       AND tc.constraint_type = 'PRIMARY KEY'
   LEFT JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
        ON kcu.table_catalog = tc.table_catalog
       AND kcu.table_schema = tc.table_schema
       AND kcu.table_name = tc.table_name
       AND kcu.constraint_name = tc.constraint_name
WHERE t.table_schema NOT IN ('pg_catalog', 'information_schema', 'plv8x')
  AND kcu.column_name IS NOT NULL
GROUP BY t.table_schema || '.' || t.table_name, kcu.constraint_name
"""

const SQL_ColumnsInfo = """
SELECT table_schema || '.' || table_name as name, array_agg('' || column_name) as columns
FROM information_schema.columns WHERE table_schema NOT IN ('pg_catalog', 'information_schema', 'plv8x') group by name;
"""
