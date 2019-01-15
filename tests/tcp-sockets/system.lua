-- system.lua

moonagents.global_functions()

local server
local client = {}
local n_success = 0
local n_failure = 0
local n_tests = 1
local ncli = 0
local params 

local T = timer(.001,"T")

local function Start(nclients, ip, port, npings, ping_int, timeout)
   n_tests = nclients or n_tests
   params = { ip, port, npings, ping_int, timeout }
-- log_print("%s: %u",name_, n_tests)
   server = create("Server", "server", ip, port)
   timer_start(T)
   next_state("Active")
end

local function Active_T()
   if ncli < n_tests then 
      client[ncli] = create(string.format("Client%u",ncli), "client", table.unpack(params))
      ncli = ncli + 1
   end
   if ncli == n_tests then 
      timer_modify(T,1,"Tmonitor")
   end
   timer_start(T)
end

local function Active_Tmonitor()
   --log_print("tests=%u, succeeded=%u, failed=%u",n_tests,n_success,n_failure)
   timer_start(T)
end


local function Finished()
   local n = n_success + n_failure
   if n == ncli then
      send_out({ "RESULTS", ncli, n_success, n_failure })
      send({ "STOP" }, server)  
      stop()
   end
end

local function Active_Success()
   n_success = n_success + 1
   Finished()
end

local function Active_Failure()
   n_failure = n_failure + 1
   log("FAILURE '%s'",signal_[2])
   Finished()
end

start_transition(Start)
transition("Active","T",Active_T)
transition("Active","Tmonitor",Active_Tmonitor)
transition("Active","SUCCESS",Active_Success)
transition("Active","FAILURE",Active_Failure)
