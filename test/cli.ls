should = (require \chai).should!
test_conString = (require \./testlib).get_dbcnn!
expect = (require \chai).expect
require! <[supertest express]>
var pgrest, plx, app
boot = {}
describe 'pgrest' -> ``it``
  .. 'loaded successfully.', (done) ->
    # Load home page
    pgrest := require \..
    pgrest.should.be.ok
    getopts = pgrest.get-opts!
    testopts = getopts!
    testopts.conString = test_conString
    _app <- pgrest.cli! testopts, {}, [], null
    app := _app
    done!
  .. 'issue', (done) ->
    supertest app
      .get '/collections/'
      .expect 'Content-Type' /json/
      .expect 200
      .end (err, res) ->
        done!
  
      
