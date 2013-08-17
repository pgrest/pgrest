#!/usr/bin/env lsc -cj
#
# PgRest Configuration
#

#------------------------
# Web Server Settings
#------------------------

# http server host
host: "0.0.0.0"
# http server port
port: "3000"
# prefix
prefix: "/collections"

#------------------------
# Database Settings
#------------------------

# database connection
dbconn: "tcp://postgres@localhost"
# database name
dbname: "mydb"
# database schema
#dbschema: "public"
