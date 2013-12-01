should = (require \chai).should!

pgrest = require \../
describe 'Plugin Validation', ->
  pgrest.use.should.be.ok
  describe 'ensures a plugin is valid.', -> ``it``
    .. 'should throw exception if a plugin does not implement isactive', (done) ->
      (-> pgrest.use {}).should.throw "plugin does not have isactive function!"
      done!
    .. 'should throw exception if a plugin uses unsupported hookname.', (done) ->
      errmsg = ["plugin uses unsupported hooks:"
                "- posthook-unsupported-hook"]
      fake-plugin = do
        process-opts: ->
        isactive: -> true
        initialize: -> true
        posthook-unsupported-hook: -> false
      (-> pgrest.use fake-plugin)
        .should.throw errmsg.join "\n"
      done!
