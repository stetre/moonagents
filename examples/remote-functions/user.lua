-- Agent script: user.lua (database user)

moonagents.global_functions()

local function Start()
   -- find the pid of the agent named "Database" (relative to the parent):
   local database = pid_of("Database", parent_)
   assert(database,"cannot find database")
   log_print("%s: Database pid is %u", name_, database)
   
   local ts
   ts = now()

   -- get an entry from the database
   ts = now()
   local i = 123
   local val = remote_call(database,"get",i)
   local elapsed = since(ts)
   log_print("%s: entry %u is '%s' (retrieved in %.6f s)", name_, i, val, elapsed)

   -- overwrite it in the database...
   ts = now()
   remote_call(database,"set",i,string.format("hello %u %u %u",1,2,3))
   log_print("%s: entry %u set in %.6f s", name_, i, since(ts))

   -- ... and then get it again
   ts = now()
   val = remote_call(database,"get",i)
   elapsed = since(ts)
   log_print("%s: entry %u is '%s' (retrieved in %.6f s)", name_, i, val, elapsed)

   -- ungracefully exit the application
   os.exit(true,true)
   -- a cleaner exit would be to send a signal to the system agent or the application,
   -- then stop() and let them handle the exit gracefully, e.g.:
   -- send({"STOPPING"}, parent_)
   -- stop()
end

start_transition(function (n)  next_state("Idle") end)
transition("Idle","START",Start)

