#!/usr/bin/env lsc -cj
author:
  name: ['Chia-liang Kao']
  email: 'clkao@clkao.org'
name: 'pgrest'
description: 'enable REST in postgres'
version: '0.1.0'
main: \lib/index.js
bin:
  pgrest: 'bin/pgrest'
repository:
  type: 'git'
  url: 'git://github.com/pgrest/pgrest.git'
scripts:
  test: """
    mocha
  """
  prepublish: """
    lsc -cj package.ls &&
    lsc -bc -o lib src
  """
  # this is probably installing from git directly, no lib.  assuming dev
  postinstall: """
    if [ ! -e ./lib ]; then npm i LiveScript; lsc -bc -o lib src; fi
  """
engines: {node: '*'}
dependencies:
  optimist: \0.6.x
  trycatch: \1.0.x
  plv8x: '>= 0.6.3'
  cors: \2.1.x
  \connect-csv : \0.0.x
  winston: \~0.7.2
  async: \0.2.x
peerDependencies:
  express: \3.4.x
devDependencies:
  express: \3.4.x
  mocha: \1.14.x
  supertest: \0.7.x
  chai: \1.8.x
  LiveScript: \1.2.x
