io-client = require 'socket.io-client'
url = require \url
events = require \events

class Ref
  (uri) ->
    {@host, @pathname} = url.parse uri
    {1:@tbl, 2:@id, 3:@col} = @pathname.split '/'

    if @col
      @refType = \column
    else if @id
      @refType = \entry
    else if @tbl
      @refType = \collection
    else
      @refType = \root

    @socket = io-client.connect "http://#{@host}", 
      transports: ['websocket']
      'force new connection': true
      'connect timeout': 999999999
      'reconnect': true
      'reconnection delay': 500
      'reopen delay': 500
    @socket.on \error ->
      console.log \error, it
      throw it

  on: (event, cb, subscribe-complete-cb) !->
    switch @refType
    case \collection
      @socket.on "#{@tbl}:#event", cb

      if event == \value
        # get current data from server and return it immediately
        @socket.emit "GETALL:#{@tbl}", -> cb? it
      <- @socket.emit "SUBSCRIBE:#{@tbl}:#event"
      subscribe-complete-cb?!
    case \entry
      switch event
      case \value
        @bare_cbs ?= {}
        filtered_cb = ->
          if it._id == @id
            cb it
        @socket.on "#{@tbl}:child_changed", filtered_cb
        @bare_cbs[cb] = filtered_cb

        @socket.emit "GET:#{@tbl}", { q: "{\"_id\": #{@id} }"}, -> cb? it.entries[0]
        <- @socket.emit "SUBSCRIBE:#{@tbl}:child_changed"
        subscribe-complete-cb?!
      case \child_added
        # NOT SUPPORTED
        subscribe-complete-cb?!
      case \child_changed
        # NOT SUPPORTED
        subscribe-complete-cb?!
      case \child_removed
        # NOT SUPPORTED
        subscribe-complete-cb?!

  set: (value, cb) ->
    switch @refType
    case \collection
      @socket.emit "PUT:#{@tbl}", { body: value }, -> cb? it
    case \entry
      @socket.emit "PUT:#{@tbl}", { body: value, u: true }, -> cb? it

  push: (value, cb) ->
    switch @refType
    case \collection
      @socket.emit "POST:#{@tbl}", { body: value }, -> cb? it
    case \entry
      throw new Error "not implemented"

  update: (value, cb) ->
    switch @refType
    case \collection
      throw new Error "not implemented"
    case \entry
      @socket.emit "PUT:#{@tbl}", { body: value, u: true }, -> cb? it

  remove: (cb) ->
    switch @refType
    case \collection
      @socket.emit "DELETE:#{@tbl}", -> cb? it
    case \entry
      @socket.emit "DELETE:#{@tbl}", { _id: @id }, -> cb? it

  off: (event, cb) ->
    switch @refType
    case \collection
      if cb
        for l in @socket.listeners "#{@tbl}:#event"
          if l == cb
            @socket.removeListener "#{@tbl}:#event", l
      else
        @socket.removeAllListeners "#{@tbl}:#event"
    case \entry
      if event == \value
        if cb
          if @bare_cbs[cb]
            @socket.removeListener "#{@tbl}:child_changed", @bare_cbs[cb]
        else
          @socket.removeAllListeners "#{@tbl}:child_changed"
      else
        #NOT SUPPORTED

  once: (event, cb, subscribe-complete-cb) ->
    switch @refType
    case \collection
      once_cb = ~>
        cb it
        @off(event, once_cb)
      @on(event, once_cb, subscribe-complete-cb)
    case \entry
      once_cb = ~>
        if it._id == @id
          cb it
          @off(event, once_cb)
      @on(event, once_cb, subscribe-complete-cb)

  toString: ->
    "http://#{@host}#{@pathname}"

  root: ->
    "http://#{@host}"

  name: ->
    switch @refType
    case \collection
      @tbl
    case \entry
      @id

  parent: ->
    switch @refType
    case \collection
      @root!
    case \entry
      "#{@root!}/#{@tbl}"

  child: ->
    switch @refType
    case \collection
      new Ref("#{@toString!}/#{it}")

exports.Ref = Ref
