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
          <- plx.conn.query q
          <- plx.conn.query t
          #TODO: only ignore err if it's about trigger alread exists

          err, result <- plx.conn.query "LISTEN pgrest_subscription_#name"
          notification_cb = ->
            tbl = it.channel.split("_")[2]
            for socket_id, socket of io.sockets.sockets
              if io.sockets.sockets[socket_id].listen_table.indexOf tbl != -1
                io.sockets.sockets[socket_id].emit "CHANNEL:#tbl", JSON.parse it.payload
          if plx.conn.listeners \notification .length == 0
            plx.conn.on \notification, notification_cb
          io.sockets.sockets[socket.id].listen_table ?= []
          io.sockets.sockets[socket.id].listen_table.push name
          cb_complete "OK"
      )(name)
  
  return names

