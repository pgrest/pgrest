export function q
  """
    '#{ "#it".replace /'/g "''" }'
  """

export function qq
  return it if it is '*'
  it.replace /\.(\d+)/g -> "[#{ parseInt(RegExp.$1) + 1}]"
    .replace /^([^.]*)/ -> "\"#{ RegExp.$1.replace /"/g '""' }\""

export function walk(model, meta)
  return [] unless meta?[model]
  for col, spec of meta[model]
    [compile(model, spec), col]

export function compile(model, field)
  {$query, $from, $and, $} = field ? {}
  switch
  | $from? => let from-table = qq "#{$from}", model-table = qq "#{model}"
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

export function cond(model, spec)
  switch typeof spec
  | \number => spec
  | \string => qq spec
  | \object =>
      # Implicit AND on all k,v
      ([ test model, qq(k), v for k, v of spec ].reduce (++)) * " AND "
  | _ => it

export function test(model, key, expr)
  switch typeof expr
  | <[ number boolean ]> => ["(#key = #expr)"]
  | \string => ["(#key = #{ q expr })"]
  | \object =>
    unless expr?
      return ["(#key IS NULL)"]
    for op, ref of expr
      switch op
      | \$not => "(NOT #{test model, key, ref})"
      | \$lt
          res = evaluate model, ref
          "(#key < #res)"
      | \$gt
          res = evaluate model, ref
          "(#key > #res)"
      | \$contains
          ref = [ref] unless Array.isArray ref
          res = q "{#{ref.join \,}}"
          "(#key @> #res)"
      | \$ => let model-table = qq "#{model}s"
          "(#key = #model-table.#{ qq ref })"
      | \$literal => "(#key = #ref)"
      | _ => throw "Unknown operator: #op"
  | \undefined => [true]

export function evaluate (model, ref)
  switch typeof ref
  | <[ number boolean ]> => "#ref"
  | \string => q ref
  | \object => for op, v of ref => switch op
      | \$ => let model-table = qq "#{model}s"
          "#model-table.#{ qq v }"
      | \$ago => "'now'::timestamptz - #{ q "#v ms" }::interval"
      | _ => continue

export function order-by(fields)
    sort = for k, v of fields
        "#{qq k} " + switch v
        |  1 => \ASC
        | -1 => \DESC
        | _  => throw "unknown order type: #q #k"
    sort * ", "

function select_columns(columns)
  (.reduce (++)) <| for name, v of columns
    if name is \*
      if Array.isArray v
        v.map qq
      else
        ['*']
    else
      if v.field
        [[v.field, name].map qq .join ' '] # as
      else if v.$literal
        [that + ' ' + qq name]
      else if v.$from
        ["""
          (SELECT COALESCE(ARRAY_TO_JSON(ARRAY_AGG(_)), '[]') FROM (
            #{build_view_source {as: v.$from, v.$query, v.$order, v.columns}}
          ) _
          ) #{qq name}"""]

export function build_view_source({as,filters,$query,$order}:meta)
  source = as
  unless source is /^SELECT/
    columns = select_columns meta.columns ? {'*': {}}
    source = "SELECT #{columns.join ", "} FROM #source"
    if $query
      source += ' WHERE ' + compile as, $query
  if filters
    source = """WITH #{ ["#filter AS (#content)" for filter, content of filters].join ",\n" }
      #source
    #{ if $query => 'AND' else 'WHERE' }
    #{ ["(select count(true) >= 0 from #filter limit 1)" for filter of filters].join " AND "}
    """

  source += " ORDER BY " + order-by $order if $order
  source
