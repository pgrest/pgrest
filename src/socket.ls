pgrest = require \..

{locate_record} = pgrest.routes!
export function mount-socket (plx, schema, io, cb)
  schema-cond = if schema
      "IN ('#{schema}')"
  else
      "NOT IN ( 'information_schema', 'pg_catalog', 'plv8x')"

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
      tbl
  mount-model-socket-event plx, scm, cols, io
  default-schema ?= \public

  cb cols

export function mount-model-socket-event (plx, schema, names, io)
  do
    # TODO: need refactoring
    socket <- io.sockets.on('connection')
    cb_complete = ->
      socket.emit "complete", it
    cb_err = ->
      socket.emit "error", it
    for name in names
      ((name) ->
        socket.on "GET:#name" !->
          it ?= {}
          if it._id
            param = locate_record plx, schema, name, it._id
            if it._column
              param.f = "#{it._column}": 1
          else
            param = it{ l, sk, c, s, q, fo, f, u, delay, body } <<< collection: "#schema.#name"
          param.$ = it.body || ""
          if it._column
            cb = (record) ->
              cb_complete record[it._column]
            plx[\select].call plx, param, cb, cb_err
          else
            plx[\select].call plx, param, cb_complete, cb_err
        socket.on "POST:#name" !->
          it ?= {}
          param = it{ l, sk, c, s, q, fo, f, u, delay, body } <<< collection: "#schema.#name"
          param.$ = it.body || ""
          plx[\insert].call plx, param, cb_complete, cb_err
        socket.on "DELETE:#name" !->
          it ?= {}
          if it._id
            param = locate_record plx, schema, name, it._id
          else
            param = it{ l, sk, c, s, q, fo, f, u, delay, body } <<< collection: "#schema.#name"
          param.$ = it.body || ""
          plx[\remove].call plx, param, cb_complete, cb_err
        socket.on "PUT:#name" !->
          it ?= {}
          if it._id
            param = locate_record plx, schema, name, it._id
          else
            param = it{ l, sk, c, s, q, fo, f, u, delay, body } <<< collection: "#schema.#name"
          param.$ = it.body || ""
          if param.u
            plx[\upsert].call plx, param, cb_complete, cb_err
          else if it._id
            plx[\upsert].call plx, param, cb_complete, cb_err
          else
            plx[\replace].call plx, param, cb_complete, cb_err
        socket.on "SUBSCRIBE:#name" !->
          q = """
            CREATE FUNCTION pgrest_subscription_trigger_#name() RETURNS trigger AS $$
            DECLARE
            BEGIN
              PERFORM pg_notify('pgrest_subscription_#name', '' || row_to_json(NEW) );
              RETURN new;
            END;
          $$ LANGUAGE plpgsql;
          """
          t = """
            CREATE TRIGGER pgrest_subscription_trigger
            AFTER INSERT
            ON #name FOR EACH ROW
            EXECUTE PROCEDURE pgrest_subscription_trigger_#name();
          """
          plx.conn.query "LISTEN pgrest_subscription_#name"
          plx.conn.on \notification ~>
            tbl = it.channel.split("_")[2]
            socket.emit "CHANNEL:#tbl", JSON.parse it.payload
          do
            err, rec <-plx.conn.query q
            #TODO: only ignore err if it's about trigger alread exists
            err, rec <- plx.conn.query t
            cb_complete "OK"
      )(name)
  
  return names

