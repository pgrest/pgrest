pgrest = require \..

export function cli(config, use, middleware, bootstrap, cb)
  if \function isnt typeof bootstrap
    bootstrap = if pkg = bootstrap
      bootstrap = (plx, cb) -> pkg.bootstrap plx, cb
    else
      (_, cb) -> cb!

  {argv} = require \optimist
  conString = argv.db or process.env['PLV8XCONN'] or process.env['PLV8XDB'] or process.env.TESTDBNAME or process.argv?2
  unless conString
    console.log "ERROR: Please set the PLV8XDB environment variable, or pass in a connection string as an argument"
    process.exit!
  {pgsock} = argv

  plx <- pgrest .new conString, config

  {mount-default,with-prefix} = pgrest.routes!

  <- bootstrap plx

  process.exit 0 if argv.boot
  {port=3000, prefix="/collections", host="127.0.0.1"} = argv
  express = try require \express
  throw "express required for starting server" unless express
  app = express!

  app.use express.json!
  for p in use
    app.use if \string is typeof p
      express[p]!
    else
      p

  if argv.cors
    require! cors
    middleware.unshift cors!

  cols <- mount-default plx, 'pgrest', with-prefix prefix, (path, r) ->
    args = [path] ++ middleware ++ r
    app.all ...args

  cb app, plx
  app.listen port, host
  console.log "Available collections:\n#{ cols.sort! * ' ' }"
  console.log "Serving `#conString` on http://#host:#port#prefix"
