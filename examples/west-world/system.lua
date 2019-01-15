-- System agent script: system.lua

moonagents.global_functions()

local T1 = timer(1,"T1_EXPIRED") -- overall duration timer
local T2 = timer(1,"T2_EXPIRED") -- update timer
local Bob, Elsa
local LastUpdate, UpdateInterval

local function Active_T1Expired()
   timer_stop(T2)
   send({"STOP"}, Bob)
   send({"STOP"}, Elsa)
   stop(function() print("\n\n -- THE END --\n") end)
end

local function Active_T2Expired()
   send({"UPDATE"}, Bob)
   send({"UPDATE"}, Elsa)
   LastUpdate = timer_start(T2, LastUpdate+UpdateInterval)
end

local function Start(duration, interval)
   assert(duration and interval)
   UpdateInterval = interval
   log_print("%s: duration=%g s, interval=%g s",name_,duration, UpdateInterval)

   -- Create the two agents for the miner and his wife:
   Bob = create("Bob", "miner")
   Elsa = create("Elsa", "wife")

   -- send both a start signal, including they respective pids:
   send({"START", Elsa}, Bob)
   send({"START", Bob}, Elsa)
   -- Start the overall duration timer:
   timer_start(T1,now()+duration)
   -- Start the update timer:
   LastUpdate = timer_start(T2, now()+UpdateInterval)
   next_state("ACTIVE")
end

start_transition(Start)
transition("ACTIVE","T1_EXPIRED",Active_T1Expired)
transition("ACTIVE","T2_EXPIRED",Active_T2Expired)

