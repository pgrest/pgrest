#!/usr/bin/env lsc -cj
author:
  name: ['Chia-liang Kao']
  email: 'clkao@clkao.org'
name: 'pgrest'
description: 'enable REST in postgres'
version: '0.0.1'
main: \lib/index.js
bin:
  pgrest: 'bin/cmd.js'
repository:
  type: 'git'
  url: 'git://github.com/clkao/pgrest.git'
scripts:
  test: """
    env PATH="./node_modules/.bin:$PATH" mocha
  """
  prepublish: """
    env PATH="./node_modules/.bin:$PATH" lsc -cj package.ls &&
    env PATH="./node_modules/.bin:$PATH" lsc -bc bin &&
    env PATH="./node_modules/.bin:$PATH" lsc -bc -o lib src
  """
engines: {node: '*'}
dependencies:
  optimist: \0.3.x
  trycatch: \*
  plv8x: 'git://github.com/clkao/plv8x.git'
devDependencies:
  mocha: \*
  chai: \*
  LiveScript: \1.1.1
  express: \3.1.x
  cors: \0.0.4
  gzippo: \0.2.x
optionalDependencies: {}
