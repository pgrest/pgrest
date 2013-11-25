io-client = require 'socket.io-client'
url = require \url
events = require \events

class Ref
  (uri, opt) ->
    {@host, @pathname} = url.parse uri
    {1:@tbl, 2:@id, 3:@col} = @pathname.split '/'

    if @col
      @refType = \column
      @id = parseInt @id, 10
    else if @id
      @refType = \entry
      @id = parseInt @id, 10
    else if @tbl
      @refType = \collection
    else
      @refType = \root

    @opt = opt
    conf = if opt?force
      transports: ['websocket']
      'force new connection': true
      'connect timeout': 999999
      'reconnect': true
      'reconnection delay': 500
      'reopen delay': 500
    else
      transports: ['websocket']
      'connect timeout': 999999
      'reconnect': true
      'reconnection delay': 500
      'reopen delay': 500
    console.log \construct, opt

    @socket = io-client.connect "http://#{@host}", conf
    @socket.on \error ->
      console.log \error, it
      throw it

  on: (event, cb) !->
    switch @refType
    case \collection
      @socket.on "#{@tbl}:#event", cb

      if event == \value
        # get current data from server and return it immediately
        <~ @socket.emit "SUBSCRIBE:#{@tbl}:#event"
        console.log "SUBSCRIBE:#{@tbl}:#event compeleted"
        <~ @socket.emit "GETALL:#{@tbl}"
        console.log "GET:#{@tbl} completed"
        cb? it
      else
        <~ @socket.emit "SUBSCRIBE:#{@tbl}:#event"
        console.log "SUBSCRIBE:#{@tbl}:#event compeleted"
    case \entry
      switch event
      case \value
        @bare_cbs ?= {}
        filtered_cb = ->
          if it._id == @id
            cb it
        @socket.on "#{@tbl}:child_changed", filtered_cb
        @bare_cbs[cb] = filtered_cb

        console.log "SUBSCRIBing:#{@tbl}:child_changed"
        <~ @socket.emit "SUBSCRIBE:#{@tbl}:child_changed"
        console.log "SUBSCRIBE:#{@tbl}:child_changed completed"
        <~ @socket.emit "GET:#{@tbl}", { _id: @id }
        console.log "GET:#{@tbl} completed"
        cb? it
      case \child_added
        ...
      case \child_changed
        ...
      case \child_removed
        ...
    case \column
      switch event
      case \value
        @bare_cbs ?= {}
        filtered_cb = ->
          if it._id == @id
            cb it[@col]
        @socket.on "#{@tbl}:child_changed", filtered_cb
        @bare_cbs[cb] = filtered_cb

        console.log "SUBSCRIBing:#{@tbl}:child_changed"
        <~ @socket.emit "SUBSCRIBE:#{@tbl}:child_changed"
        console.log "SUBSCRIBE:#{@tbl}:child_changed completed"
        <~ @socket.emit "GET:#{@tbl}", { _id: @id, _column: @col }
        console.log "GET:#{@tbl} completed"
        cb? it
      case \child_added
        ...
      case \child_changed
        ...
      case \child_removed
        ...

  set: (value, cb) ->
    switch @refType
    case \collection
      @socket.emit "PUT:#{@tbl}", { body: value }, -> cb? it
    case \entry
      @socket.emit "PUT:#{@tbl}", { body: value, u: true }, -> cb? it
    case \column
      @socket.emit "PUT:#{@tbl}", { _id: @id, body: { "#{@col}": value }, u: true}, -> cb? it

  push: (value, cb) ->
    switch @refType
    case \collection
      @socket.emit "POST:#{@tbl}", { body: value }, -> cb? it
    case \entry
      ...
    case \column
      ...

  update: (value, cb) ->
    switch @refType
    case \collection
      ...
    case \entry
      @socket.emit "PUT:#{@tbl}", { body: value, u: true }, -> cb? it
    case \column
      ...

  remove: (cb) ->
    switch @refType
    case \collection
      @socket.emit "DELETE:#{@tbl}", -> cb? it
    case \entry
      @socket.emit "DELETE:#{@tbl}", { _id: @id }, -> cb? it
    case \column
      @socket.emit "PUT:#{@tbl}", { _id: @id, body: { "#{@col}": null }, u: true}, -> cb? it

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
        ...
        console.log \mooooooooooooooooooooooooo
    case \column
      if event == \value
        if cb
          if @bare_cbs[cb]
            @socket.removeListener "#{@tbl}:child_changed", @bare_cbs[cb]
        else
          @socket.removeAllListeners "#{@tbl}:child_changed"
      else
        ...

  once: (event, cb) ->
    switch @refType
    case \collection
      once_cb = ~>
        @off(event, once_cb)
        cb it
      @on(event, once_cb)
    case \entry
      once_cb = ~>
        if it._id == @id
          @off(event, once_cb)
          cb it
      @on(event, once_cb)
    case \column
      once_cb = ~>
          @off(event, once_cb)
          cb it
      @on(event, once_cb)

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
    case \column
      @col

  parent: ->
    switch @refType
    case \collection
      @root!
    case \entry
      "#{@root!}/#{@tbl}"
    case \column
      "#{@root!}/#{@tbl}/#{@id}"

  child: ->
    console.log \child, it, @opt
    switch @refType
    case \collection
      new Ref("#{@toString!}/#{it}", @opt)
    case \entry
      new Ref("#{@toString!}/#{it}", @opt)
    case \column
      ...

exports.Ref = Ref
