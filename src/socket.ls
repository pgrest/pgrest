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
    socket <- io.sockets.on('connection')
    cb_err = ->
      console.log it
      socket.emit "error", it
    for name in names
      ((name) ->
        for verb in <[ GET POST PUT DELETE GETALL ]>
          ((verb) ->
            socket.on "#verb:#name" !->
              if arguments.length == 2
                p = arguments[0]
                cb = arguments[1]
              else
                p = {}
                cb = arguments[0]
              if verb == \GETALL
                cols <- plx.query "SELECT * FROM #name"
                cb cols
              else
                if p._id
                  param = locate_record plx, schema, name, p._id
                else
                  param = p{ l, sk, c, s, q, fo, f, u, delay, body } <<< collection: "#schema.#name"
                param.$ = p.body || ""

                if p._column
                  callback = (record) ->
                    cb record[p._column]
                else
                  callback = cb

                method = switch verb
                | \GET    => \select
                | \POST   => \insert
                | \PUT    => (if param.u or p._id then \upsert else \replace)
                | \DELETE => \remove
                plx[method].call plx, param, callback, cb_err
          )(verb)
        for event in <[ value child_added child_changed child_removed ]>
          ((event) ->
            socket.on "SUBSCRIBE:#name:#event" !->
              cb = arguments[0]
              return_val = switch event
              | \child_removed => " '' || row_to_json(OLD)"
              | _              => " '' || row_to_json(NEW)"
              q = """
                DROP FUNCTION IF EXISTS pgrest_subscription_trigger_#{name}_#{event}();
                CREATE FUNCTION pgrest_subscription_trigger_#{name}_#{event}() RETURNS trigger AS $$
                DECLARE
                BEGIN
                  PERFORM pg_notify('pgrest_subscription_#{name}_#{event}', #return_val);
                  RETURN new;
                END;
                $$ LANGUAGE plpgsql;
              """
              trigger_event = switch event
              | \value         => "INSERT OR UPDATE OR DELETE"
              | \child_added   => \INSERT
              | \child_changed => \UPDATE
              | \child_removed => \DELETE
              t = """
                CREATE TRIGGER pgrest_subscription_trigger_#event
                AFTER #trigger_event
                ON #name FOR EACH ROW
                EXECUTE PROCEDURE pgrest_subscription_trigger_#{name}_#{event}();
              """
              e, r <- plx.conn.query q
              e, r <- plx.conn.query t
              err, result <- plx.conn.query "LISTEN pgrest_subscription_#{name}_#{event}"
              notification_cb = ->
                tbl = it.channel.split('_')[2]
                event = it.channel.split('_').slice 3 .join \_
                row = it.payload
                for socket_id, socket of io.sockets.sockets
                  if io.sockets.sockets[socket_id].listen_table?indexOf "#tbl:#event" != -1
                    if event == \value
                      cols <- plx.query "SELECT * FROM #tbl"
                      io.sockets.sockets[socket_id].emit "#tbl:value", cols
                    else
                      io.sockets.sockets[socket_id].emit "#tbl:#event", JSON.parse row
              if plx.conn.listeners \notification .length == 0
                plx.conn.on \notification, notification_cb
              io.sockets.sockets[socket.id]?listen_table ?= []
              io.sockets.sockets[socket.id]?listen_table.push "#name:#event"

              cb \OK
          )(event)
      )(name)
  
  return names

