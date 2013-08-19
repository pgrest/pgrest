``#!/usr/bin/env node``
# Import
# -------------------------
pgrest = require \..

# Main
# -------------------------
get-opts = pgrest.get-opts!
opts = get-opts!

middleware = []

if opts.app
  bootstrap = reqire opts.app
else
  bootstrap = null
  
app <- pgrest.cli! opts, <[cookieParser]>, middleware, bootstrap