require! {express, optimist, plv8x}
conString = process.env.PGRESTCONN
conString ||= "tcp://localhost/#{ process.env.TESTDBNAME }" if process.env.TESTDBNAME
app = express!

plx <- (require \./).new conString

app.get '/collections', (req, res) ->
  res.setHeader 'Content-Type', 'application/json; charset=UTF-8'
  res.end JSON.stringify { }

mount-model = (name) ->
  app.get "/collections/#name", (req, resp) ->
    param = req.query{ l, sk, c, s, q } <<< { collection: name }
    try
      body <- plx.select param
      resp.setHeader 'Content-Type' 'application/json; charset=UTF-8'
      resp.end body
    catch
      return resp.end "error: #e"

rows <- plx.query """
  SELECT t.table_name tbl FROM INFORMATION_SCHEMA.TABLES t WHERE t.table_schema = 'public';
"""
for {tbl} in rows => mount-model tbl

app.listen 3000
console.log 'Listening on port 3000'
