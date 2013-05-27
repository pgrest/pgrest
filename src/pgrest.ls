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
    trycatch do
      -> done fn.call req, -> done it
      -> it.=message if it instanceof Error; switch typeof it
      | \number => resp.send it, { error: it }
      | \object => resp.send 500 it
      | \string => (if it is /^\d\d\d$/
        then resp.send it, { error: it }
        else resp.send 500 { error: "#it" })
      | _       => resp.send 500 { error: "#it" }

export function derive-type (content, type)
  TypeMap = Boolean: \boolean, Number: \numeric, String: \text, Array: 'text[]', Object: \plv8x.json
  TypeMap[typeof! content || \plv8x.json]


export function mount-model (schema, name, route=route)
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
