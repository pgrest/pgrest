``#!/usr/bin/env node``
# Import
# -------------------------
pgrest = require \..

# Main
# -------------------------
get-opts = pgrest.get-opts!
opts = get-opts!

pgparam = (req, res, next) ->
  if opts.cookiename
    session = req.cookies[opts.cookiename]
    req.pgparam = {session}
  next!

middleware = [pgparam]

if opts.app
  bootstrap = reqire opts.app 
else
  bootstrap = null
  
app <- pgrest.cli! opts, <[cookieParser]>, middleware, bootstrap