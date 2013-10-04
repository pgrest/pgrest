should = (require \chai).should!
expect = (require \chai).expect

{build_view_source} = require \../lib/sql.js

function same_sql(a, b)
  a.=replace /\s+/g, ' ' .replace /^\s+|\s+$/g ''
  b.=replace /\s+/g, ' ' .replace /^\s+|\s+$/g ''
  expect a .to.equal b

describe 'View Builder', ->
  describe 'is excepted build from metadata', -> ``it``
    .. 'Simple view', (done) ->
      same_sql """
        SELECT * FROM calendar
      """, build_view_source do
        as: 'calendar'
      done!
    .. 'Simple view with condition', (done) ->
      same_sql """
        SELECT * FROM calendar WHERE (NOT ("ad" IS NULL))
      """, build_view_source do
        as: 'calendar'
        $query: ad: $not: null
      done!

    .. 'Simple view with columns', (done) ->
      same_sql """
        SELECT "ad", "session" FROM calendar WHERE (NOT ("ad" IS NULL))
      """, build_view_source do
        as: 'calendar'
        columns: '*': <[ad session]>
        $query: ad: $not: null
      done!

    .. 'Simple view with functional columns', (done) ->
      same_sql """
        SELECT *, _calendar_sitting_id(calendar) "sitting_id"
        FROM calendar WHERE (NOT ("ad" IS NULL))
      """, build_view_source do
        columns:
          '*': {}
          sitting_id: $literal: '_calendar_sitting_id(calendar)'
        as: 'calendar'
        $query: ad: $not: null
      done!

    .. 'view with relation columns', (done) ->
      same_sql """
        SELECT *,
          (SELECT COALESCE(ARRAY_TO_JSON(ARRAY_AGG(_)), '[]')
           FROM ( SELECT "calendar".id "calendar_id", "chair", "date", "time_start", "time_end"
                 FROM pgrest.calendar
                 WHERE ("sitting_id" = sittings.id) ORDER BY "id" ASC ) _ ) "dates"
        FROM public.sittings
      """, build_view_source do
        columns:
          '*': {}
          dates:
            $from: 'pgrest.calendar'
            $query: 'sitting_id': $literal: 'sittings.id'
            $order: {id: 1}
            columns:
              'calendar_id': field: 'calendar.id'
              '*': <[chair date time_start time_end]>
        as: 'public.sittings'
      done!
