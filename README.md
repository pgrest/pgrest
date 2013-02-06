pgrest
======

WARNING: this is work in progress and everything is likely to change!

```
npm i
npm run prepublish
./node_modules/.bin/plv8x --db tcp://localhost/MYDB --import pgrest:./package.json
./node_modules/.bin/plv8x --db tcp://localhost/MYDB --inject 'plv8x_json pgrest_select(plv8x_json)=pgrest:pgrest_select'
```
