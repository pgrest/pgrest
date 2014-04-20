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
  require! program: commander

  # add options here
  # format: commander.option <long, short option> [description] [parser] [default]
  program.version "PgRest v" + (require require.resolve \../package.json).version

  program.option '--config [config-file]' 'config file' ((cfg) -> require path.resolve "#{cfg}"), {}
  program.option '--host [host]' 'Host'
  program.option '--port [port]' 'Port'
  program.option '--prefix [prefix]' 'Prefix for endpoints'
  program.option '--meta [meta]' 'metadata'
  program.option '--schema [schema]' 'Schema information'
  program.option '--boot' 'boot'
  program.option '--cors' 'cors'
  program.option '--cookiename [cookiename]' 'cookie'
  program.option '--with-plugins [plugings]' 'plugins' parse-pluginsargv
  program.option '--db [db]' 'conString'
  program.option '--pgsock [pgsock]' 'pg socket'

  program.parse process.argv

  ## Helpers
  # split argv into an Array
  parse-pluginsargv = ->
    switch typeof it
      case \string then it / ' '
      case \object then it

  # get db connecting string 
  get_db_conn = ->
    # retrieve conString from following locations
    conString = program.db \
      or process.env['PLV8XCONN'] \
      or process.env['PLV8XDB'] \
      or process.env.TESTDBNAME \
      or if cfg.dbconn and cfg.dbname then "#{cfg.dbconn}/#{cfg.dbname}" else ""

    # if pgsock option is given, return options with host and database
    pgsock = (conString) ->
      * host: program.pgsock
        database: conString

    return if program.pgsock then pgsock conString else conString

  cfg = program.config


  opts = do
    host: program.host or cfg.host or "127.0.0.1"
    port: program.port or cfg.port or "3000"
    prefix: program.prefix or cfg.prefix or "/collections"
    conString: get_db_conn!
    meta: program.meta or cfg.meta or {}
    schema: program.schema or cfg.dbschema or 'public'
    boot: program.boot or cfg.boot or false
    cors: program.cors or cfg.cors or false
    cookiename: program.cookiename or cfg.cookiename or null
    plugins: parse-pluginsargv program.withPlugins or cfg['with-plugins'] or []
    argv: program
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
