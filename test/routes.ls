should = (require \chai).should!
test_conString = (require \./testlib).get_dbcnn!
expect = (require \chai).expect
require! <[supertest express]>
var pgrest, plx, app
boot = {}
describe 'pgrest' -> ``it``
  .. 'loaded successfully.', (done) ->
    # Load home page
    conString = test_conString
    pgrest := require \..
    pgrest.should.be.ok
    _plx <- pgrest.new conString, boot
    plx := _plx
    done!
  .. 'test data', (done) ->
    res <- plx.query """
    DROP TABLE IF EXISTS issue;
    DROP TABLE IF EXISTS initiative;
    CREATE TABLE issue (
        id int not null primary key,
        title text not null,
        last_update timestamp
    );
    CREATE TABLE initiative (
        id int not null primary key,
        issue_id int not null,
        title text not null,
        last_update timestamp
    );
    INSERT INTO issue (id, title, last_update) values(1, 'test', NOW());
    INSERT INTO initiative (id, issue_id, title, last_update) values(1, 1, 'test 1', NOW());
    INSERT INTO initiative (id, issue_id, title, last_update) values(2, 2, 'test 2', NOW());
    """
    done!
  .. 'express routes', (done) ->
    {mount-default,with-prefix} = pgrest.routes!
    app := express!
    app.use express.cookieParser!
    app.use express.json!
    cols <- mount-default plx, null, with-prefix '/collections', -> app.all.apply app, &
    done!
  .. 'issue', (done) ->
    supertest app
      .get '/collections/issue'
      .expect 'Content-Type' /json/
      .expect 200
      .end (err, res) ->
        expect res.body.entries.length .to.equal 1
        done!
