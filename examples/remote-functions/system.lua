-- System agent script: system.lua

moonagents.global_functions()

start_transition(function (n_entries)
   -- create the database process
   create("Database","database",n_entries)

   -- create the user process and send it a START signal
   create("User","user")
   send({ "START" }, offspring_)

   stop()
end)

