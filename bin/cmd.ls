``#!/usr/bin/env node``
# Import
# -------------------------
pgrest = require \..

# Main
# --------------------------------------------------------------------
get-opts = pgrest.get-opts!
opts = get-opts!  
app <- pgrest.cli! opts, {}, [], null
