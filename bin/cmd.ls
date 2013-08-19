``#!/usr/bin/env node``
# Import
# -------------------------
pgrest = require \..

# Main
# -------------------------
get_opts = pgrest.get_opts!
opts = get_opts!

middleware = []

if opts.app
  bootstrap = reqire opts.app
else
  bootstrap = null
  
app <- pgrest.cli! opts, <[cookieParser]>, middleware, bootstrap