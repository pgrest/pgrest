io-client = require 'socket.io-client'
url = require \url
events = require \events

class CollectionRef
  (uri, opt) ->
    {@host, @pathname} = url.parse uri
    {1:@tbl, 2:@id, 3:@col} = @pathname.split '/'

    if @tbl and !@id and !@col
      @refType = \collection
    else
      throw "#{@pathname} is not a collection"

    @opt = opt
    conf =
      transports: ['websocket']
      'connect timeout': 999999
      'reconnect': true
      'reconnection delay': 500
      'reopen delay': 500
    if @opt?force
      conf['force new connection']= true

    @socket = io-client.connect "http://#{@host}", conf
    @socket.on \error ->
      console.log \error, it
      throw it

  on: (event, cb) !->
    @socket.on "#{@tbl}:#event", cb

    if event == \value
      # get current data from server and return it immediately
      <~ @socket.emit "SUBSCRIBE:#{@tbl}:#event"
      <~ @socket.emit "GETALL:#{@tbl}"
      cb? it
    else
      <~ @socket.emit "SUBSCRIBE:#{@tbl}:#event"

  set: (value, cb) ->
    @socket.emit "PUT:#{@tbl}", { body: value }, -> cb? it

  push: (value, cb) ->
    @socket.emit "POST:#{@tbl}", { body: value }, -> cb? it

  update: (value, cb) ->
    ...

  remove: (cb) ->
    @socket.emit "DELETE:#{@tbl}", -> cb? it

  off: (event, cb) ->
    if cb
      for l in @socket.listeners "#{@tbl}:#event"
        if l == cb
          @socket.removeListener "#{@tbl}:#event", l
    else
      @socket.removeAllListeners "#{@tbl}:#event"

  once: (event, cb) ->
    once_cb = ~>
      @off(event, once_cb)
      cb it
    @on(event, once_cb)

  toString: ->
    "http://#{@host}#{@pathname}"

  root: ->
    "http://#{@host}"

  name: ->
    @tbl

  parent: ->
    ...

  child: ->
    new Ref("#{@toString!}/#{it}", @opt)

class ColumnRef
  (uri, opt) ->
    {@host, @pathname} = url.parse uri
    {1:@tbl, 2:@id, 3:@col} = @pathname.split '/'

    if @tbl and @id and @col
      @refType = \column
      @id = parseInt @id, 10
    else
      throw "#{@pathname} is not a column"

    @opt = opt
    conf =
      transports: ['websocket']
      'connect timeout': 999999
      'reconnect': true
      'reconnection delay': 500
      'reopen delay': 500
    if @opt?force
      conf['force new connection']= true

    @socket = io-client.connect "http://#{@host}", conf
    @socket.on \error ->
      console.log \error, it
      throw it

  on: (event, cb) !->
    switch event
    case \value
      @bare_cbs ?= {}
      filtered_cb = ->
        if it._id == @id
          cb it[@col]
      @socket.on "#{@tbl}:child_changed", filtered_cb
      @bare_cbs[cb] = filtered_cb

      <~ @socket.emit "SUBSCRIBE:#{@tbl}:child_changed"
      <~ @socket.emit "GET:#{@tbl}", { _id: @id, _column: @col }
      cb? it
    case \child_added
      ...
    case \child_changed
      ...
    case \child_removed
      ...

  set: (value, cb) ->
    @socket.emit "PUT:#{@tbl}", { _id: @id, body: { "#{@col}": value }, u: true}, -> cb? it

  push: (value, cb) ->
    ...

  update: (value, cb) ->
    ...

  remove: (cb) ->
    @socket.emit "PUT:#{@tbl}", { _id: @id, body: { "#{@col}": null }, u: true}, -> cb? it

  off: (event, cb) ->
    if event == \value
      if cb
        if @bare_cbs[cb]
          @socket.removeListener "#{@tbl}:child_changed", @bare_cbs[cb]
      else
        @socket.removeAllListeners "#{@tbl}:child_changed"
    else
      ...

  once: (event, cb) ->
    once_cb = ~>
        @off(event, once_cb)
        cb it
    @on(event, once_cb)

  toString: ->
    "http://#{@host}#{@pathname}"

  root: ->
    "http://#{@host}"

  name: ->
    @col

  parent: ->
    new Ref("#{@root!}/#{@tbl}/#{@id}", @opt)

  child: ->
    ...
      
class EntryRef
  (uri, opt) ->
    {@host, @pathname} = url.parse uri
    {1:@tbl, 2:@id, 3:@col} = @pathname.split '/'

    if @tbl and @id and !@col
      @refType = \entry
      @id = parseInt @id, 10
    else
      throw "#{@pathname} is not an entry"

    @opt = opt
    conf =
      transports: ['websocket']
      'connect timeout': 999999
      'reconnect': true
      'reconnection delay': 500
      'reopen delay': 500
    if @opt?force
      conf['force new connection']= true

    @socket = io-client.connect "http://#{@host}", conf
    @socket.on \error ->
      console.log \error, it
      throw it

  on: (event, cb) !->
    switch event
    case \value
      @bare_cbs ?= {}
      filtered_cb = ->
        if it._id == @id
          cb it
      @socket.on "#{@tbl}:child_changed", filtered_cb
      @bare_cbs[cb] = filtered_cb

      <~ @socket.emit "SUBSCRIBE:#{@tbl}:child_changed"
      <~ @socket.emit "GET:#{@tbl}", { _id: @id }
      cb? it
    case \child_added
      ...
    case \child_changed
      ...
    case \child_removed
      ...

  set: (value, cb) ->
    @socket.emit "PUT:#{@tbl}", { body: value, u: true }, -> cb? it

  push: (value, cb) ->
    ...

  update: (value, cb) ->
    @socket.emit "PUT:#{@tbl}", { body: value, u: true }, -> cb? it

  remove: (cb) ->
    @socket.emit "DELETE:#{@tbl}", { _id: @id }, -> cb? it

  off: (event, cb) ->
    if event == \value
      if cb
        if @bare_cbs[cb]
          @socket.removeListener "#{@tbl}:child_changed", @bare_cbs[cb]
      else
        @socket.removeAllListeners "#{@tbl}:child_changed"
    else
      ...

  once: (event, cb) ->
    once_cb = ~>
      if it._id == @id
        @off(event, once_cb)
        cb it
    @on(event, once_cb)

  toString: ->
    "http://#{@host}#{@pathname}"

  root: ->
    "http://#{@host}"

  name: ->
    @id

  parent: ->
    new Ref("#{@root!}/#{@tbl}", @opt)

  child: ->
    new Ref("#{@toString!}/#{it}", @opt)

class Ref
  (uri, opt) ->
    {@host, @pathname} = url.parse uri
    {1:@tbl, 2:@id, 3:@col} = @pathname.split '/'

    if @col
      return new ColumnRef( uri, opt )
    else if @id
      return new EntryRef( uri, opt )
    else if @tbl
      return new CollectionRef( uri, opt )


exports.Ref = Ref
