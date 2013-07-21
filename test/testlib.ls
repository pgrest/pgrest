exports.get_dbcnn = ->
  throw "environment variable TESTDBNAME is required" unless process.env.TESTDBNAME
  prefix = if process.env.TESTDBUSERNAME 
    then "#{ process.env.TESTDBUSERNAME}@"	
    else ''
  "tcp://#{prefix}localhost/#{ process.env.TESTDBNAME }"
