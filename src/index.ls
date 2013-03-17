require! plv8x
exports.new = (conString, cb) ->
  throw "Expected: new(dsn, cb) where dsn is 'db', 'host/db' or 'tcp://host/db'" unless conString
  conString = "localhost/#conString" unless conString is // / //
  conString = "tcp://#conString"     unless conString is // :/ //
  plx <- plv8x.new conString
  <- plx.import-bundle \pgrest require.resolve(\../package.json)
  <- plx.eval -> plv8x_require \pgrest .boot!
  err <- plx.conn.query plv8x._mk_func \pgrest_boot {} \boolean plv8x.plv8x-lift "pgrest", "boot"
  throw err if err
  <[ select upsert insert replace remove ]>.forEach (method) ->
    plx[method] = (param, cb, onError) ->
      err, { rows:[ {ret} ] }? <- @conn.query "select pgrest_#method($1) as ret" [JSON.stringify param]
      return onError?(err) if err
      cb? ret
    err <- plx.conn.query plv8x._mk_func "pgrest_#method" {param: \plv8x.json} \plv8x.json plv8x.plv8x-lift "pgrest", method
    throw err if err
  plx.query = (...args) ->
    cb = args.pop!
    err, { rows }? <- @conn.query ...args
    throw err if err
    cb? rows
  plx.end = -> plx.conn.end!
  return cb plx if cb
  return plx.conn.end!

q = -> """
    '#{ "#it".replace /'/g "''" }'
"""

qq = ->
    it.replace /\.(\d+)/g -> "[#{ parseInt(RegExp.$1) + 1}]"
      .replace /^(\w+)/ -> "#{ RegExp.$1.replace /"/g '""' }"

walk = (model, meta) ->
    return [] unless meta?[model]
    for col, spec of meta[model]
        [compile(model, spec), col]

compile = (model, field) ->
    {$query, $from, $and, $} = field ? {}
    switch
    | $from? => let from-table = qq "#{$from}s", model-table = qq "#{model}s"
        """
        (SELECT COALESCE(ARRAY_TO_JSON(ARRAY_AGG(_)), '[]') FROM (SELECT * FROM #from-table
            WHERE #{ qq "_#model" } = #model-table."_id" AND #{
                switch
                | $query?                   => cond model, $query
                | _                         => true
            }
        ) AS _)
        """
    | $? => cond model, $
    | typeof field is \object => cond model, field
    | _ => field

cond = (model, spec) -> switch typeof spec
    | \number => spec
    | \string => qq spec
    | \object =>
        # Implicit AND on all k,v
        ([ test model, qq(k), v for k, v of spec ].reduce (++)) * " AND "
    | _ => it

test = (model, key, expr) -> switch typeof expr
    | <[ number boolean ]> => ["(#key = #expr)"]
    | \string => ["(#key = #{ q expr })"]
    | \object =>
        unless expr?
            return ["(#key IS NULL)"]
        for op, ref of expr
            switch op
            | \$not =>
                "(NOT #{test model, key, ref})"
            | \$lt =>
                res = evaluate model, ref
                "(#key < #res)"
            | \$gt =>
                res = evaluate model, ref
                "(#key > #res)"
            | \$contains =>
                ref = [ref] unless Array.isArray ref
                res = q "{#{ref.join \,}}"
                "(#key @> #res)"
            | \$ => let model-table = qq "#{model}s"
                "(#key = #model-table.#{ qq ref })"
            | _ => throw "Unknown operator: #op"
    | \undefined => [true]

evaluate = (model, ref) -> switch typeof ref
    | <[ number boolean ]> => "#ref"
    | \string => q ref
    | \object => for op, v of ref => switch op
        | \$ => let model-table = qq "#{model}s"
            "#model-table.#{ qq v }" 
        | \$ago => "'now'::timestamptz - #{ q "#v ms" }::interval"
        | _ => continue

order-by = (fields) ->
    sort = for k, v of fields
        "#{qq k} " + switch v
        |  1 => \ASC
        | -1 => \DESC
        | _  => throw "unknown order type: #q #k"
    sort * ", "

export function select(param)
    for p in <[l sk c]> | typeof param[p] is \string => param[p] = parseInt param[p]
    for p in <[q s]>    | typeof param[p] is \string => param[p] = JSON.parse param[p]
    {collection, l = 30, sk = 0, q, c, s, fo} = param
    cond = compile collection, q if q

    id-column = plv8.pgrest.PrimaryFieldOf[collection]
    query = "SELECT *#{ if id-column then ", #id-column AS _id" else "" } FROM #{ qq collection }"

    query += " WHERE #cond" if cond?
    [{count}] = plv8.execute "select count(*) from (#query) cnt"
    return { count } if c

    query += " ORDER BY " + order-by s if s
    return (plv8.execute "#query limit $1 offset $2" [l, sk])?0 if fo
    do
        paging: { count, l, sk }
        entries: plv8.execute "#query limit $1 offset $2" [l, sk]
        query: cond

export function remove(param)
  for p in <[q]> | typeof param[p] is \string => param[p] = JSON.parse param[p]
  {collection, $, q} = param
  cond = compile collection, q if q
  query = "DELETE FROM #{ qq collection }"
  query += " WHERE #cond" if cond?
  plv8.execute query
  return insert(param)

export function replace(param)
  remove param
  return insert param

export function insert(param)
  {collection, $} = param
  return (for $set in (if Array.isArray $ then $ else if $ then [$] else [])
    insert-cols = [k for k of $set]
    continue unless insert-cols.length
    insert-vals = [v for _,v of $set]
    query = "INSERT INTO #{ qq collection }(#{insert-cols.map qq .join \,}) VALUES (#{["$#{i+1}" for it,i in insert-cols].join \,})"
    plv8.execute query, insert-vals)

export function upsert(param)
    for p in <[u delay]> | typeof param[p] is \string => param[p] = parseInt param[p]
    # XXX derive q from $set and table constraints
    for p in <[q]> | typeof param[p] is \string => param[p] = JSON.parse param[p]
    {collection, u, $={}, q, delay} = param
    {$set={}} = $
    cond = compile collection, q if q
    cols = [k for k of $set]
    vals = [v for _,v of $set]
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
        query = "INSERT INTO #{ qq collection }(#{insert-cols.map qq .join \,}) VALUES (#{["$#{i+1}" for it,i in insert-cols].join \,})"
        res = try
          plv8.execute query, insert-vals
        catch e
          throw e unless e is /violates unique constraint/
        return {+inserted} if res


export function boot()
    serial = 0
    deferred = []
    ``console`` = { log: -> plv8.elog(WARNING, ...arguments) }
    ``setTimeout`` = (fn, ms=0) -> deferred.push [fn, ms + (serial++ * 0.001)]
    ``pgprocess`` = do
        nextTick: (fn) -> setTimeout fn
        next: ->
            doit = (-> return unless deferred.length; deferred.shift!0!; doit!)
            doit!
    PrimaryFieldOf = {}
    for {key, val, constraint} in plv8.execute SQL_PrimaryFieldInfo | val.length is 1
      # console.log "PrimaryFieldOf(#key) = #val (#constraint)"
      PrimaryFieldOf[key] = val.0
    plv8.pgrest = { PrimaryFieldOf }
    return true

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
