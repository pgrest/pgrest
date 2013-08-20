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

#-------------------------------
# Database settings
#-------------------------------
dbconn: "tcp://postgres@localhost"
dbname: "mydb"
dbschema: "kuansim"
#meta:
#  'pgrest.info': {+fo}
#  'pgrest.member_count': {+fo}
#  'pgrest.contingent': {}
#  'pgrest.issue':
#    as: 'public.issue'
#  'pgrest.initiative':
#    as: 'public.initiative'

#-------------------------------
# Authnication and Authorization
#-------------------------------
auth:
  enable: true
  success_redirect: "/"
  logout_redirect: "/"
  # Actived auth plugins
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
