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

    @socket = io-client.connect "http://#{@host}", {transports: ['websocket'], 'force new connection': true}
    @socket.on \error ->
      console.log \error, it
      throw it

  on: (event, cb, subscribe-complete-cb) !->
    @socket.on "#{@tbl}:#event", cb

    if event == \value
      # get current data from server and return it immediately
      @socket.emit "GETALL:#{@tbl}", -> cb? it
    <~ @socket.emit "SUBSCRIBE:#{@tbl}:#event"
    subscribe-complete-cb?!

  set: (value, cb) ->
    @socket.emit "PUT:#{@tbl}", { body: value }, -> cb? it

  push: (value, cb) ->
    @socket.emit "POST:#{@tbl}", { body: value }, -> cb? it

  remove: (value, cb) ->
    @socket.emit "DELETE:#{@tbl}", -> cb? it

  off: (event, cb) ->
    if cb
      for l in @socket.listeners "#{@tbl}:#event"
        if l == cb
          @socket.removeListener "#{@tbl}:#event", l
    else
      @socket.removeAllListeners "#{@tbl}:#event"

  once: (event, cb, subscribe-complete-cb) ->
    once_cb = ~>
      cb it
      @off(event, once_cb)
    @on(event, once_cb, subscribe-complete-cb)

  toString: ->
    "http://#{@host}#{@pathname}"

  root: ->
    "http://#{@host}"

  name: ->
    @tbl

  parent: ->
    return @root!

exports.Ref = Ref
