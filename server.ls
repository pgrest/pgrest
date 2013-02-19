require! {express, optimist, plv8x}
conString = process.env.PGRESTCONN
app = express!

conn = plv8x.connect conString
<- plv8x.bootstrap conn

app.get '/collections', (req, res) ->
  res.setHeader 'Content-Type', 'application/json; charset=UTF-8'
  res.end JSON.stringify { }

mount-model = (name) ->
    app.get "/collections/#name", (req, resp) ->
        param = req.query{l, sk, c, s, q} <<< { collection: name}
        try
            for p in <[l sk c]> when param[p]? => param[p] = parseInt param[p]
            for p in <[q s]> when param[p]? => param[p] = JSON.parse param[p]
        catch
            return resp.end "error: #e"
        err, res <- conn.query "select pgrest_select($1) as ret" [JSON.stringify param]
        return resp.end "error: #err" if err
        body = res.rows.0.ret
        resp.setHeader 'Content-Type' 'application/json; charset=UTF-8'
        resp.end body

mount-model \bills
mount-model \motions

app.listen 3000
console.log 'Listening on port 3000'
