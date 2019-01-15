-- system.lua

moonagents.global_functions()
local ts = now() -- timestamp

local delays = {} -- delays returned by agents

local T = timer(0.0001,"T") -- "create" timer

local n_agents = 1000 -- number of agents
local stopped = 0    -- number of agents that stopped
local agent = {}     -- agents' pids
local next_agent = 1
   
local function Stats(data)
-- Computes mean, variance, minimum and maximum
-- over the sequence of numbers contained in data
   local max,min = 0, math.huge
   local mean, delta, m2, var = 0, 0, 0, 0
   for i=1,#data do 
      local d = data[i]
      if d < min then min = d end
      if d > max then max = d end
      delta = d - mean
      mean = mean + delta/i
      m2 = m2 + delta*(d-mean)
   end
   if #data > 1 then var = m2/(#data-1) end
   return  mean, var, min, max
end


local function Active_T()
   create(nil,"agent")
   agent[next_agent] = offspring_
   send({ "STOP" }, offspring_)
   if next_agent < n_agents then
      next_agent = next_agent +1
      timer_start(T)
   end
end

local function Start(n) 
   n_agents = n or n_agents
   timer_start(T)
   next_state("Active")
end

local function Active_Stopping()
   stopped = stopped+1
   delays[#delays+1] = signal_[2] -- signals' delays
   if stopped == n_agents then
      local elapsed = since(ts)
      local mean, var, min, max = Stats(delays)
      send_out({ "RESULTS", n_agents, elapsed, mean, var, min, max })
      stop()
   end
end

start_transition(Start)
transition("Active", "T" , Active_T)
transition("Active", "STOPPING", Active_Stopping)

