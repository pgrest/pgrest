should = (require \chai).should!
expect = (require \chai).expect
mk-pgrest-fortest = (require \./testlib).mk-pgrest-fortest
provide-dbconn = (require \./testlib).provide-dbconn
require! <[supertest express]>
var pgrest, app
describe 'CLI', ->
  beforeEach (done) ->
    pgrest := require \..
    pgrest.should.be.ok
    getopts = pgrest.get-opts!
    testopts = getopts!
    testopts.conString = provide-dbconn!
    _app <- pgrest.cli! testopts, {}, [], null
    app := _app
    done!
  describe '#cli()', -> ``it``
    .. 'should pass all routing tests', (done) ->
      supertest app
        .get '/collections/'
        .expect 'Content-Type' /json/
        .expect 200
        .end (err, res) ->
          res.body.should.deep.eq []
          done!
  
      
