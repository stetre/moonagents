-- Agent script

-- The moonagents table is preloaded in the agent's _ENV, so it need not be require()d.
-- local moonagents = require("moonagents") -- this should give an error

-- Make moonagents functions global in this _ENV:
moonagents.global_functions()

-- Just to make things a little interesting, the salute is given with a delay.
local delay = 1.2 -- seconds
local T = timer(delay,"T_EXPIRED")

local function Start()
   print("Please, wait "..delay.." seconds ...")
   timer_start(T)
   next_state("Waiting")
end

local function TExpired()
   print("... Hello World!")
   stop()
end

start_transition(Start)
transition("Waiting", "T_EXPIRED", TExpired)

