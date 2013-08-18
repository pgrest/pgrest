``#!/usr/bin/env node``
# Import
# -------------------------
require! optimist
require! plv8x
require! path

express = try require \express
throw "express required for starting server" unless express

require! cors
require! \connect-csv

pgrest = require \..

# Helper Functions
# @FIXME: move these fucntion to src and added testcases.
# --------------------------
ensured_opts = ->
  unless it.conString
    console.log "ERROR: Please set the PLV8XDB environment variable, or pass in a connection string as an argument"
    process.exit!
  it

get_opts = ->
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
    schema: argv.schema or cfg.schema or 'public'
    auth: cfg.auth or [enable: false]
    cookie_name: cfg.cookie_name or null
  console.log opts
  ensured_opts opts

# Main
# --------------------------------------------------------------------
{argv} = optimist
if argv.version
  {version} = require require.resolve \../package.json
  console.log "PgRest v#{version}"
  process.exit 0

opts = get_opts!
plx <- pgrest .new opts.conString, opts.meta
{mount-default, mount-auth, with-prefix} = pgrest.routes!

process.exit 0 if argv.boot

app = express!
app.use express.json!
app.use connect-csv header: \guess
  
if opts.auth.enable
  require! passport
  app.use express.cookieParser!
  app.use express.bodyParser!
  app.use express.methodOverride!
  app.use express.session secret: 'test'  
  app.use passport.initialize!
  app.use passport.session!
  mount-auth plx, app, opts
  
pgparam = (req, res, next) ->
  if req.isAuthenticated!
    console.log "#{req.path} user is authzed. init db sesion"
    req.pgparam = [{auth:req.user}]
  else
    console.log "#{req.path} user is not authzed. reset db session"
    req.pgparam = {}

  if opts.cookie_name?
    req.pgparam.session = req.cookies[opts.cookie_name]    
  next!

cols <- mount-default plx, opts.schema, with-prefix opts.prefix, (path, r) ->
  args = [pgparam, r]
  args.unshift cors! if argv.cors
  args.unshift path
  app.all ...args
  # for debug
  app.get '/isauthz', ensure_authz, (req, res) ->
    [pgrest_param:result] <- plx.query '''select pgrest_param()'''
    row? <- plx.query "select getauth()"
    console.log row
    res.send result          

app.listen opts.port, opts.host
console.log "Available collections:\n#{ cols * ' ' }"
console.log "Serving `#{opts.conString}` on http://#{opts.host}:#{opts.port}#{opts.prefix}"
