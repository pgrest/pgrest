require! path
require! http
pgrest = require \..

ensured-opts = ->
  unless it.conString
    console.log "ERROR: Please set the PLV8XDB environment variable, or pass in a connection string as an argument"
    process.exit!
  unless it.prefix
    console.log "ERROR: Please set the prefix"
    process.exit!
  unless it.port
    console.log "ERROR: Please set the port"
    process.exit!
  unless it.host
    console.log "ERROR: Please set the host"
    process.exit!
  it

export function get-opts
  {argv} = require \optimist
  if argv.version
    {version} = require require.resolve \../package.json
    console.log "PgRest v#{version}"
    process.exit 0

  if argv.config
    cfg = require path.resolve "#{argv.config}"
  else
    cfg = {}      
  get_db_conn = ->
    if cfg.dbconn and cfg.dbname
      conString = "#{cfg.dbconn}/#{cfg.dbname}"
    else if argv.pgsock
      conString = "postgres:localhost/#{pgsock}"
    else
      conString = argv.db \
        or process.env['PLV8XCONN'] \
        or process.env['PLV8XDB'] \
        or process.env.TESTDBNAME \
        or process.argv?2
  opts = do
    host: argv.host or cfg.host or "127.0.0.1"
    port: argv.port or cfg.port or "3000"
    prefix: argv.prefix or cfg.prefix or "/collections"
    conString: get_db_conn!
    meta: cfg.meta or {}
    auth: cfg.auth or {}
    schema: argv.schema or cfg.dbschema or 'public'
    boot: argv.boot or false
    cors: argv.cors or false
    cookiename: argv.cookiename or cfg.cookiename or null
    app: argv.app or cfg.appname or null

mk-pgparam = (enabled_auth, cookiename)->
  pgparam = (req, res, next) ->
    req.pgparam = {}
    if enabled_auth
      if req.isAuthenticated!
        console.log "#{req.path} user is authzed. init db sesion"
        req.pgparam.auth = req.user
      else
        console.log "#{req.path} user is not authzed. reset db session"
        req.pgparam = {}
          
    if cookiename?
      req.pgparam.session = req.cookies[cookiename]    
    next!
  pgparam

export function cli(__opts, use, middleware, bootstrap, cb)
  if !Object.keys __opts .length
    __opts = get-opts!
  opts = ensured-opts __opts

  #@FIXME: not test yet.
  if not bootstrap? and opts.app?
    bootstrap = require opts.app 
  
  if \function isnt typeof bootstrap
    bootstrap = if pkg = bootstrap
      bootstrap = (plx, cb) -> pkg.bootstrap plx, cb
    else
      (_, cb) -> cb!

  plx <- pgrest .new opts.conString, opts.meta

  {mount-default,mount-auth,with-prefix} = pgrest.routes!


  <- bootstrap plx

  process.exit 0 if opts.boot

  express = try require \express
  throw "express required for starting server" unless express
  app = express!

  app.use express.json!
  for p in use
    app.use if \string is typeof p
      express[p]!
    else
      p

  if opts.cors
    require! cors
    middleware.unshift cors!

  middleware.push mk-pgparam opts.auth.enable, opts.cookiename
  
  if opts.auth.enable
    require! passport
    app.use express.cookieParser!
    app.use express.bodyParser!
    app.use express.methodOverride!
    app.use express.session secret: 'test'
    app.use passport.initialize!
    app.use passport.session!
    mount-auth plx, app, middleware, opts
          
  cols <- mount-default plx, opts.schema, with-prefix opts.prefix, (path, r) ->
    args = [path] ++ middleware ++ r
    app.all ...args

  server = http.createServer app
  <- server.listen opts.port, opts.host, 511
  console.log "Available collections:\n#{ cols.sort! * ' ' }"
  console.log "Serving `#{opts.conString}` on http://#{opts.host}:#{opts.port}#{opts.prefix}"
  if cb
    cb app, plx, server
