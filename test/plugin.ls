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

describe 'Plugin', ->
  describe 'should be able to hook cli.', -> ``it``
    .. 'should be able to hook option processing.', (done) ->
      opts = {}
      fake-plugin = do
        isactive: -> true
        process-opts: (opts) -> opts.test = 1
      pgrest.use fake-plugin
      pgrest.init-plugins! opts
      opts.test.should.eq 1
      done!
    .. 'should be able to do initialize.', (done) ->
      fake-plugin = do
        initialized: false
        isactive: -> true
        initialize: -> @initialized = true
      fake-plugin.initialized.should.not.be.ok
      pgrest.use fake-plugin
      pgrest.init-plugins! null
      fake-plugin.initialized.should.be.ok
      done!
