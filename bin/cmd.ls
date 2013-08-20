``#!/usr/bin/env node``
# Import
# -------------------------
pgrest = require \..

# Main
# --------------------------------------------------------------------
get-opts = pgrest.get-opts!
opts = get-opts!
  
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

middleware = [pgparam]

if opts.app
  bootstrap = reqire opts.app 
else
  bootstrap = null
  
app <- pgrest.cli! opts, <[cookieParser]>, middleware, bootstrap
