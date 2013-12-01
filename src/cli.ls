require! path
require! http
require! winston
pgrest = require \..

ensured-opts = ->
  unless it.conString
    winston.error "ERROR: Please set the PLV8XDB environment variable, or pass in a connection string as an argument"
    process.exit!
  unless it.prefix
    winston.error "ERROR: Please set the prefix"
    process.exit!
  unless it.port
    winston.error "ERROR: Please set the port"
    process.exit!
  unless it.host
    winston.error "ERROR: Please set the host"
    process.exit!
  it

export function get-opts
  {argv} = require \optimist
  if argv.version
    {version} = require require.resolve \../package.json
    winston.info "PgRest v#{version}"
    process.exit 0

  if argv.config
    cfg = require path.resolve "#{argv.config}"
  else
    cfg = {}
  get_db_conn = ->
    if cfg.dbconn and cfg.dbname
      conString = "#{cfg.dbconn}/#{cfg.dbname}"
    else
      conString = argv.db \
        or process.env['PLV8XCONN'] \
        or process.env['PLV8XDB'] \
        or process.env.TESTDBNAME \
        or process.argv?2
    if argv.pgsock
      conString = do
        host: argv.pgsock
        database: conString
    return conString
  opts = do
    host: argv.host or cfg.host or "127.0.0.1"
    port: argv.port or cfg.port or "3000"
    prefix: argv.prefix or cfg.prefix or "/collections"
    conString: get_db_conn!
    meta: cfg.meta or {}
    schema: argv.schema or cfg.dbschema or 'public'
    boot: argv.boot or false
    cors: argv.cors or false
    cookiename: argv.cookiename or cfg.cookiename or null
    app: argv.app or cfg.appname or null
    websocket: argv.websocket or false
    argv: argv
    cfg: cfg

pgparam-init = (req, res, next) ->
  req.pgparam = {}
  next!

pgparam-session = (cookiename)->
  (req, res, next) ->
    if cookiename?
      req.pgparam.session = req.cookies[cookiename]
    next!

export function cli(__opts, use, middleware, bootstrap, cb)
  if !Object.keys __opts .length
    __opts = get-opts!
  opts = ensured-opts __opts
  pgrest.init-plugins! opts

  #@FIXME: not test yet.
  if not bootstrap? and opts.app?
    bootstrap = require opts.app

  if \function isnt typeof bootstrap
    bootstrap = if pkg = bootstrap
      bootstrap = (plx, cb) -> pkg.bootstrap plx, cb
    else
      (_, cb) -> cb!

  plx <- pgrest.new opts.conString, {opts.meta}
  pgrest.invoke-hook! \posthook-cli-create-plx, opts, plx

  {mount-default,mount-auth,with-prefix} = pgrest.routes!

  <- bootstrap plx

  process.exit 0 if opts.boot

  express = try require \express
  throw "express required for starting server" unless express
  app = express!
  pgrest.invoke-hook! \posthook-cli-create-app, opts, app

  app.use express.json!
  for p in use
    app.use if \string is typeof p
      express[p]!
    else
      p

  if opts.cors
    require! cors
    middleware.unshift cors!

  middleware.push pgparam-init
  if opts.cookiename
    middleware.push pgparam-session opts.cookiename

  pgrest.invoke-hook! \prehook-cli-mount-default, opts, plx, app, middleware
  cols <- mount-default plx, opts.schema, with-prefix opts.prefix, (path, r) ->
    args = [path] ++ middleware ++ r
    app.all ...args

  server = http.createServer app
  pgrest.invoke-hook! \posthook-cli-create-server, opts, server

  <- server.listen opts.port, opts.host, 511
  pgrest.invoke-hook! \posthook-cli-server-listen, opts, plx, app, server
  winston.info "Available collections:\n#{ cols.sort! * ' ' }"
  winston.info "Serving `#{opts.conString}` on http://#{opts.host}:#{opts.port}#{opts.prefix}"
  if cb
    cb app, plx, server
