-- Agent script: database.lua (database process)

moonagents.global_functions()

local database = {}

local function set(i,val) -- 'set' method
   log_print("%s: set(%u)='%s'", name_, i, val)   
   database[i]=val
   return database[i]
end

local function get(i) -- 'get' method
   log_print("%s: get(%u)='%s'", name_, i, database[i]) 
   return database[i]
end

start_transition(function(n) 
   -- populate the database
   log_print("%s: populating database with %u entries", name_, n)   
   for i=1,n do
      database[i] = string.format("entry no %u",i);
   end

   -- export the get/set functions for remote calls
   export_function("set",set)
   export_function("get",get)

   -- not important in this example
   next_state("_") 
end)

