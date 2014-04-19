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
  /*
  Parse options from argv, config file or default setting (hard-code)
  Priority: argv -> config file -> default setting

  for all parameters' detail, please go to wiki:
  https://github.com/pgrest/pgrest/wiki/CLI-Parameters
  */

  # first time parsing for obtaining config file content
  {argv} = require \optimist
  cfg = if argv.config then require path.resolve "#{argv.config}" else {}

  ## Helpers
  # split argv into an Array
  parse-pluginsargv = ->
    switch typeof it
      case \string then it / ' '
      case \object then it

  # get db connecting string 
  get_db_conn = ->
    if cfg.dbconn and cfg.dbname
      # if there are \dbconn and \dbname in config file
      conString = "#{cfg.dbconn}/#{cfg.dbname}"
    else
      # or just from argv or environment variables
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

  # second time parsing with the full option list
  {argv, showHelp} = require \optimist
    .option \help do
      description: "Show this help"
    .option \version do
      description: "Show version info"
    .option \host do
      default: cfg.host or "127.0.0.1"
      description: "the host for PgREST"
    .option \port do
      default: cfg.port or "3000"
      description: "the port for PgREST"
    .option \prefix do
      default: cfg.prefix or "/collections"
      description: ""
    .option \meta do
      default: cfg.meta or {}
      description: ""
    .option \schema do
      default: cfg.dbschema or \public
      description: ""
    .option \boot do
      default: cfg.boot or false
      description: ""
    .option \cors do
      default: cfg.cors or false
      description: ""
    .option \cookiename do
      default: cfg.cookiename or null
      description: ""
    .option \with-plugins do
      default: cfg.with-plugins or []
      description: ""
    .option \db do
      default: ""
      description: ""

  # if 'version' appears, show up version information
  if argv.version
    {version} = require require.resolve \../package.json
    winston.info "PgRest v#{version}"
    process.exit 0

  # if 'help' appears, show up the usage document
  if argv.help
    showHelp!
    process.exit 0

  opts = do
    host: argv.host
    port: argv.port
    prefix: argv.prefix
    conString: get_db_conn!
    meta: argv.meta
    schema: argv.schema
    boot: argv.boot
    cors: argv.cors
    cookiename: argv.cookiename
    plugins: parse-pluginsargv argv['with-plugins']
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
  for plugin-name in opts.plugins
    modname = "pgrest-#plugin-name"
    plugin = try require modname
    throw "#modname is required!"  unless plugin
    pgrest.use plugin
  pgrest.init-plugins! opts

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
