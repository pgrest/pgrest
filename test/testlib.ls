should = (require \chai).should!

exports.mk-pgrest-fortest = (cb) ->
  pgrest = require \..
  pgrest.should.be.ok
  pgrest.new 'tcp://postgres@localhost/mydb', {}, cb