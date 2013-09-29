#!/usr/bin/env lsc -cj
author:
  name: ['Chia-liang Kao']
  email: 'clkao@clkao.org'
name: 'pgrest'
description: 'enable REST in postgres'
version: '0.0.7'
main: \lib/index.js
bin:
  pgrest: 'bin/cmd.ls'
repository:
  type: 'git'
  url: 'git://github.com/clkao/pgrest.git'
scripts:
  test: """
    mocha
  """
  prepublish: """
    lsc -cj package.ls &&
    lsc -bc bin &&
    chmod 755 bin/cmd.js &&
    lsc -bc -o lib src
  """
  postinstall: """
    lsc -cj package.ls &&
    lsc -bc bin &&
    chmod 755 bin/cmd.js &&
    lsc -bc -o lib src
  """
engines: {node: '*'}
dependencies:
  optimist: \0.3.x
  trycatch: \0.2.4
  plv8x: \0.5.x
  express: \3.1.x
  cors: \0.0.x
  \connect-csv : \*
  LiveScript: \1.1.1
  winston: \~0.7.2
  async: \0.2.x
devDependencies:
  mocha: \*
  supertest: \0.7.x
  chai: \*
optionalDependencies:
  passport: \0.1.x
  'passport-facebook': \1.0.x
  'passport-twitter': \1.0.x
  'passport-google-oauth': \0.1.x
