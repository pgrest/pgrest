require! plv8x
exports.new = (conString, cb) ->
  plx <- plv8x.new conString
  <- plx.import-bundle \pgrest require.resolve(\../package.json)
  <- plx.eval -> plv8x_require \pgrest .boot!
  err <- plx.conn.query plv8x._mk_func \pgrest_boot {} \boolean plv8x.plv8x-lift "pgrest", "boot"
  throw err if err
  err <- plx.conn.query plv8x._mk_func \pgrest_select {param: \plv8x.json} \plv8x.json plv8x.plv8x-lift "pgrest", "pgrest_select"
  throw err if err
  plx.select = (param, cb) ->
    err, { rows:[ {ret} ] }? <- @conn.query "select pgrest_select($1) as ret" [JSON.stringify param]
    throw err if err
    cb? ret
  plx.query = (...args) ->
    cb = args.pop!
    err, { rows } <- @conn.query ...args
    throw err if err
    cb? rows
  cb? plx

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
        for op, ref of expr
            switch op
            | \$lt =>
                res = evaluate model, ref
                "(#key < #res)"
            | \$gt =>
                res = evaluate model, ref
                "(#key > #res)"
            | \$ => let model-table = qq "#{model}s"
                "#key = #model-table.#{ qq ref }"
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

export function pgrest_select(param)
    for p in <[l sk c]> | typeof param[p] is \string => param[p] = parseInt param[p]
    for p in <[q s]>    | typeof param[p] is \string => param[p] = JSON.parse param[p]
    {collection, l = 30, sk = 0, q, c, s, fo} = param
    cond = compile collection, q if q
    query = "SELECT * from #collection"

    query += " WHERE #cond" if cond?
    [{count}] = plv8.execute "select count(*) from (#query) cnt"
    return { count } if c

    query += " ORDER BY " + order-by s if s
    do
        paging: { count, l, sk }
        entries: plv8.execute "#query limit $1 offset $2" [l, sk]
        query: cond

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
    true
