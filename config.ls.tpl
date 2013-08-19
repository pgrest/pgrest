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
# cookie name
#cookiename: ''

# pgrest meta 
#meta:
#  'pgrest.info': {+fo}
#  'pgrest.member_count': {+fo}
#  'pgrest.contingent': {}
#  'pgrest.issue':
#    as: 'public.issue'
#  'pgrest.initiative':
#    as: 'public.initiative'

#------------------------
# Database Settings
#------------------------

# database connection
dbconn: "tcp://postgres@localhost"
# database name
dbname: "mydb"
# database schema
#dbschema: "public"
