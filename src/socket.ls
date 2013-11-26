pgrest = require \..
require! async

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
  default-schema ?= \public
  <- mount-model-socket-event plx, scm, cols, io
  cb cols

create-func-trigger-on-table = (plx, names, io, cb) ->
  sql-func = (name, event) ->
    return_val = switch event
    | \child_removed => " '' || row_to_json(OLD)"
    | _              => " '' || row_to_json(NEW)"
    """
      DROP FUNCTION IF EXISTS pgrest_subscription_trigger_#{name}_#{event}();
      CREATE FUNCTION pgrest_subscription_trigger_#{name}_#{event}() RETURNS trigger AS $$
      DECLARE
      BEGIN
        PERFORM pg_notify('pgrest_subscription_#{name}_#{event}', #return_val);
        RETURN NULL;
      END;
      $$ LANGUAGE plpgsql;
    """
  sql-trigger = (name, event) ->
    trigger_event = switch event
    | \child_added   => \INSERT
    | \child_changed => \UPDATE
    | \child_removed => \DELETE
    t = """
      DROP TRIGGER IF EXISTS pgrest_subscription_trigger_#event on #name;
      CREATE TRIGGER pgrest_subscription_trigger_#event
      AFTER #trigger_event
      ON #name FOR EACH ROW
      EXECUTE PROCEDURE pgrest_subscription_trigger_#{name}_#{event}();
    """
  notification_cb = ->
    tbl = it.channel.split('_')[2]
    event = it.channel.split('_').slice 3 .join \_
    row = it.payload
    sockets-registered-on-event = []
    sockets-registered-value-event = []
    for socket_id, socket of io.sockets.sockets
      if io.sockets.sockets[socket_id].listen_table
        sockets-registered-on-event.push socket_id if io.sockets.sockets[socket_id].listen_table.indexOf("#tbl:#event") != -1
        sockets-registered-value-event.push socket_id if io.sockets.sockets[socket_id].listen_table.indexOf("#tbl:value") != -1

    for socket_id in sockets-registered-on-event
      io.sockets.sockets[socket_id].emit "#tbl:#event", JSON.parse row

    if sockets-registered-value-event.length > 0
      cols <- plx.query "SELECT * FROM #tbl"
      for socket_id in sockets-registered-value-event
        io.sockets.sockets[socket_id].emit "#tbl:value", cols

  all-funcs = for event in <[ child_added child_changed child_removed ]>
    for name in names
      ((event, name) ->
        (done) ->
          e, r <- plx.conn.query sql-func(name, event)
          e, r <- plx.conn.query sql-trigger(name, event)
          e, r <- plx.conn.query "LISTEN pgrest_subscription_#{name}_#{event}"
          done!
      )(event, name)
  <- async.series all-funcs.reduce (++)
  plx.conn.on \notification, notification_cb
  cb!


export function mount-model-socket-event (plx, schema, names, io, done)
  <- create-func-trigger-on-table plx, names, io
  do
    socket <- io.sockets.on('connection')
    cb_err = ->
      socket.emit "error", it
    for name in names
      for verb in <[ GET POST PUT DELETE GETALL ]>
        ((name, verb) ->
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
        )(name, verb)
      for event in <[ value child_added child_changed child_removed ]>
        ((event, name) ->
          socket.on "SUBSCRIBE:#name:#event", (cb) ->
            io.sockets.sockets[socket.id]?listen_table ?= []
            io.sockets.sockets[socket.id]?listen_table.push "#name:#event"

            cb \OK
        )(event, name)

  done? names


