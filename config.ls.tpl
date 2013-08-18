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
#cookie_name: ''

#------------------------
# Database Settings
#------------------------

# database connection
dbconn: "tcp://postgres@localhost"
# database name
dbname: "mydb"
# database schema
#dbschema: "public"

#-------------------------------
# Authnication and Authorization
#-------------------------------
auth:
  enable: false
  success_redirect: "/"
  logout_redirect: "/"
  # Active auth plugins
  plugins: ['facebook']
  providers_settings:
    facebook:
      clientID: ''
      clientSecret: ''
    twitter:
      consumerKey: null
      consumerSecret: null
    google:
      consumerKey: null
      consumerSecret: null
