--=============================================================================
-- MoonAgents - SDL agents engine                                                       
--=============================================================================

if moonagents._for_scripts then 
   error("cannot require() moonagents in agents scripts")
end

local moonagents = moonagents -- require("moonagents")
local moonagents_for_scripts = { } -- moonagents table as seen by the agent scripts
moonagents_for_scripts._for_scripts = true

local array = require("moonagents.array")
local fifo = require("moonagents.fifo")

local now = moonagents.now
local since = moonagents.since
local bug = error -- errors that probably are MoonAgents bugs
local format = string.format
local gsub = string.gsub
local gmatch = string.gmatch
local find = string.find
local table_concat = table.concat
local table_unpack = table.unpack
local tointeger = math.tointeger
local min = math.min
local NEVER = math.huge

local function CopyTable(t)
-- Returns a copy of table t (NOT a deep copy: its elements are copied by reference)
   local tt = {}
   for k, v in pairs(t) do tt[k] = v end
   return tt
end

local function Split(s, sep)
   local sep = sep or '.'
   local t = {}
   local pattern = "([^"..sep.."]+)"
   for ss in gmatch(s, pattern) do t[#t+1] = ss end
   return t
end

-- Get a local reference of the timers C functions, then hide them to the application:
local timers_init = moonagents.timers_init; moonagents.timers_init = nil
local timers_reset = moonagents.timers_reset; moonagents.timers_reset = nil
local timers_create = moonagents.timers_create; moonagents.timers_create = nil
local timers_start = moonagents.timers_start; moonagents.timers_start = nil
local timers_stop = moonagents.timers_stop; moonagents.timers_stop = nil
local timers_trigger = moonagents.timers_trigger; moonagents.timers_trigger = nil
local timers_tnext = moonagents.timers_tnext; moonagents.timers_tnext = nil
local timers_delete = moonagents.timers_delete; moonagents.timers_delete = nil
local timers_isrunning = moonagents.timers_isrunning; moonagents.timers_isrunning = nil
local timers_discard = moonagents.timers_discard; moonagents.timers_discard= nil
local timers_signame = moonagents.timers_signame; moonagents.timers_signame = nil
local timers_duration = moonagents.timers_duration; moonagents.timers_duration = nil
local timers_set_signame = moonagents.timers_set_signame; moonagents.timers_set_signame = nil
local timers_set_duration = moonagents.timers_set_duration; moonagents.timers_set_duration = nil
local timers_check_owner = moonagents.timers_check_owner; moonagents.timers_check_owner = nil
local tts_send = moonagents.tts_send; moonagents.tts_send = nil
local tts_pop = moonagents.tts_pop; moonagents.tts_pop = nil
local tts_tnext = moonagents.tts_tnext; moonagents.tts_tnext = nil
local tts_reset = moonagents.tts_reset; moonagents.tts_reset = nil

local DEFAULT_STARTUP, DEFAULT_DASH, DEFAULT_ASTERISK = '?', '-', '*' 
local Startup, Dash, Asterisk = DEFAULT_STARTUP, DEFAULT_DASH, DEFAULT_ASTERISK
local Special = { ['startup']=true, ['dash']='true', ['asterisk']=true }

local DEFAULT_PATH = "?;?.lua"
moonagents.path = DEFAULT_PATH -- path to scripts (package.path like)
-- get path from MOONAGENTS_PATH, if defined
local p = os.getenv("MOONAGENTS_PATH")
if p then -- substitute any ';;' with the default path:
   moonagents.path = gsub(p, ";;", function () return ";"..DEFAULT_PATH..";" end)
end

local SystemPid -- system agent pid
local SystemRunning = false
local NextPid = 1       -- next pid to be assigned
local ENV = {}          -- agents' Lua environments table, indexed by pid
local ENV_TEMPLATE      -- template for agent's dedicated environment

local Scheduler, Scheduler1 = false, false -- normal signals scheduler
local PrioSchedulers, PrioSchedulers1 = false, false -- priority schedulers 1(high)..PrioLevels(low)
local NormSignals, PrioSignals = 0, 0 -- no. of scheduled signals 
local PrioLevels = 1 -- no. of priority levels (normal scheduler corresponds to PrioLevels+1, ie lowest)
local MAX_PRIO_LEVELS = 16
local ReleaseQueue = fifo() -- agents to be released
local ReleaseFlag = false -- true if there are agents to be released


local function ResetSystem()
-- Reset the system (do not reset optional configurations , though)
   SystemPid = nil
   SystemRunning = false
   moonagents_ = nil
   timers_reset()
   tts_reset()
   ENV = {}
   PidStack = {}
   Scheduler, Scheduler1 = false, false
   PrioSchedulers, PrioSchedulers1 = false, false
   NormSignals, PrioSignals = 0, 0
   NextPid = 1
   CanCreateTimers = false
   RdSet = array()
   WrSet = array()
   ReleaseQueue = fifo()
   ReleaseFlag = false
end

----------------------------------------------------------------------------
-- Agent's dedicated _ENV
----------------------------------------------------------------------------
--
-- _ENV is set to ENV[pid] when the agent identified by pid is the current.
-- ENV[pid] is the dedicated Lua environment for the agent, where its script
-- is executed and the following (locally-global) special variables are set:
--
--
--    self_       the agent's pid
--    name_       the agent's name
--    parent_     parent's pid
--    state_      current state
--    signal_     current signal
--    signame_    current signal name (same as signal_[1])
--    sender_     sender of the current signal (pid or tid)
--    caller_     pid of original caller pid (nil if the agent is not a procedure)
--    sendtime_   send time of the current signal
--    recvtime_   receive time of the current signal
--    exptime_    time of expiration of the current signal
--    istimer_    true if the current signal is from a timer
--    offspring_  pid of the last created agent
--
-- Each agent also has, in its environment, a dedicated global table called 'moonagent_'.
-- This table contains relevant state for internal use only and must not be touched in
-- any way by the agent script code.
--
-- moonagents_ = {
--    names = {} or nil,   name <-> pid map
--    children = array(),  pids of (direct) children
--    timers = array(),    tids of timers owned by this agent
--    states = {},         state-machine table
--    defstate = nil,      default state ("asterisk" state)
--    saved = fifo(),      saved signals queue
--    exportedfunc = {},   list of exported functions (exportedfunc["funcname"]=func)
--    startfunc = nil,     start transition function
--    procedure = nil,     pid of called procedure where to redirect signals
--    atreturn = nil,      function to be called when the procedure returns 
--                         or next_state (string) or nil
--    atstopfunc = nil,    function to be called when the agent actually terminates
--    inputpriority = {}   priorities for input signals
--
-- Note: there is no more distinction here between block and process agents, since
-- it only complicates things and is not really necessary: if you want an agent to be
-- a block, just treat it like a block (can we call it a "duck block"?)
-- In SDL: A block agent can contain processes or blocks, a process agent can contain
--         only other processes (SDL-2000 for New Millennium Systems - R. Reed)
-- (A block can contain blocks and processes but not both, a process cannot contain
--  blocks nor processes. )
--

--=============================================================================
-- Logs
--=============================================================================

local logfilename      -- log file name
local logfile          -- log file handle
local log_on = false   -- logs enabled
local trace_on = false -- traces enabled
--@@TODO? local metrics_on = false -- metrics traces enabled

local function LogPreamble0() return nil end -- no preamble

local function LogPreamble1()
   local s = format("%f [%d] ", now(), self_ or 0)
   return s
end

--[[
local function LogPreamble2(tag) -- alternative with agent name instead of pid
   local s = format("%f [%s]", now(), name_ or "application", t or "")
   return s
end
--]]

local LogPreamble = LogPreamble1

local function SetLogPreamble(func)
   if func~=nil and type(func)~='function' then error("invalid argument") end
   LogPreamble = func and func or LogPreamble0
   Log("set_log_preamble (%s)", func or 'nil')
end

local function Log(formatstring, ...)
   if not log_on then return end
   logfile:write(LogPreamble() or "")
   logfile:write(format(formatstring,...))
   logfile:write("\n")
end

local function Trace(formatstring, ...)
-- Check externally when calling this: if trace_on then Trace(...) end
   logfile:write(LogPreamble() or "")
   logfile:write(format(formatstring,...))
   logfile:write("\n")
end

local function LogPrint(formatstring,...)
   local s = format(formatstring,...)
   print(s)
   Log(s)
end

local function LogClose()
   if not logfile then return end
   logfile:close()
   log_on, trace_on = false, false
   logfile, logfilename = nil, nil
end

local function LogOpen(fname)
   if type(fname)~='string' then error("missing or invalid filename") end
   if logfile then LogClose() end
   local file, errmsg = io.open(fname, "w")
   if not file then error(errmsg) end
   log_on = true
   logfilename = fname
   logfile = file
   Log("%s - MoonAgents system logfile %s", os.date(), logfilename)
   Log("Software version: %s (%s)", moonagents._VERSION, _VERSION)
   return logfile
end

local function LogFile()
   if not logfile then return nil, "no logfile" end
   return logfile, logfilename
end

local function TraceEnable(on)
   if type(on)~='boolean' then error("invalid argument") end
   if not logfile then return end
   trace_on = on
end

local function LogEnable(on)
   if type(on)~='boolean' then error("invalid argument") end
   if not logfile then return end
   log_on = on
end

local function LogFlush()
   if not logfile then return end
   logfile:flush()
end

--=============================================================================
-- Timers                                                                     
--=============================================================================

local function TimersCallback(tid, pid, signame)
-- A timer expired. There is only one timer callback, and it is always executed
-- in the application's _ENV because timers_trigger() is called from there.
   local sendtime = now()
   if trace_on then Trace("timer %u (%s) expired", tid, signame) end -- NB: this trace is from pid [0]
   Scheduler:push({{signame}, tid, pid, sendtime, NEVER, true})
   NormSignals = NormSignals + 1
end

local CanCreateTimers = false

local function Timer(duration, signame)
   if not CanCreateTimers then error("cannot create timer after startup") end
   local tid = timers_create(self_, duration, signame)
   if not moonagents_.timers then moonagents_.timers = array() end
   moonagents_.timers:insert(tid)
   if trace_on then Trace("creating timer %u (%s), duration %f", tid, signame, duration) end
   return tid
end

local function TimerStop(tid)
   timers_check_owner(tid, caller_ or self_)
   if trace_on then Trace("timer_stop %u (%s)", tid, timers_signame(tid)) end
   return timers_stop(tid)
end

local function TimerModify(tid, duration, signame)
   timers_check_owner(tid, caller_ or self_)
   if duration then timers_set_duration(tid, duration) end
   if signame then timers_set_signame(tid, signame) end
   if trace_on then
      Trace("timer_modify %u (%s), duration %f", tid, timers_signame(tid), timers_duration(tid))
   end
end

local function TimerDelete(tid) 
-- Local only: SDL does not provide means to delete a timer (they are deleted with their owners).
   timers_check_owner(tid, caller_ or self_)
   if trace_on then Trace("deleting timer %u (%s)", tid, timers_signame(tid)) end
   timers_delete(tid)
   moonagents_.timers:remove(tid)
end

local function TimerStart(tid, at)
   timers_check_owner(tid, caller_ or self_)
   if tonumber(at)~=at then error("invalid expiration time (at)") end
   local at = timers_start(tid, at)
   if trace_on then Trace("timer_start %u (%s) at %f", tid, timers_signame(tid), at) end
   return at
end

local function TimerRunning(tid)
   timers_check_owner(tid, caller_ or self_)
   return timers_isrunning(tid) 
end

--=============================================================================
-- Context switch
--=============================================================================

local PidStack = {} -- stack of pids for switching between agents

local function SwitchTo(pid, noerr)
-- Switch to the _ENV of the agent identified by pid (ie make it current).
-- If pid is unknown, the behaviour depends on the value of 'noerr':
-- 1) noerr==false or nil: raises an error
-- 2) noerr==true: leaves the current agent unchanged and return false 
--  (in this case the caller must not call the corresponding SwitchBack())
   local env = ENV[pid]
   if not env then
      if noerr then return false else bug(format("unknown pid %d", pid)) end
   end
   -- Push the pid of the current agent on the pid stack
   PidStack[#PidStack+1] = self_
   -- if trace_on then Trace("SwitchTo ->%d [%s]", pid, table_concat(PidStack, ",")) end
   _ENV = env -- set the agent as current 
   return true
end

local function SwitchBack()
-- Switch back to the _ENV of the previous agent on the stack
   if #PidStack == 0 then bug("too many SwitchBack() calls") end
   local pid = PidStack[#PidStack]
   -- if trace_on then Trace("SwitchBack ->%d [%s]", pid, table_concat(PidStack, ",")) end
   local env = ENV[pid]
   if not env then bug(format("SwitchBack to %d (exited)", pid)) end
   _ENV = env
   PidStack[#PidStack]=nil
end

--=============================================================================
-- Agent creation                                                              
--=============================================================================

local function LoadScript(scriptname)
-- Similar to loadfile(scriptname), but returns a loader that
-- accepts the environment as parameter (see PIL3/14.5)
   local f, errmsg = io.open(scriptname, "r")
   if not f then return nil, errmsg end
   local ld = "local _ENV=... " .. f:read("*a")
   f:close()
   local loader, errmsg = load(ld, format("@%s", scriptname))
   if not loader then return nil, errmsg end
   return loader
end

local Loaders = {}   -- Loaders[script] = { loader, fullname }

local function SearchScript(script)
-- Searches script and loads it (if not already loaded)
   local ld = Loaders[script]
   if ld then return ld end 
   ld = {}
   local fullname, errmsg = package.searchpath(script, moonagents.path)
   if not fullname then return nil, errmsg end
   -- Cache the loaded script for future use
   -- (this saves time when creating a lot of agents with the same script)
   local loader, errmsg = LoadScript(fullname)
   if not loader then return nil, errmsg end
   ld.fullname = fullname
   ld.loader = loader
   Loaders[script] = ld
   return ld
end

--xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
local function NewAgent(isprocedure, atreturn, name, script, ...)
--xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
-- isprocedure = true if procedure, false otherwise
   -- local ts = now()
   if name and (type(name)~='string' or find(name, '%.')) then error("invalid name") end
   if type(script)~='string' then error("missing or invalid script") end
   if atreturn and type(atreturn)~='function' and type(atreturn)~='string' then
      error("invalid atreturn")
   end

   -- Assign pid
   local pid = NextPid
   if ENV[pid] ~= nil then bug("NextPid in use") end -- very unlikely
   NextPid = NextPid + 1
   if not SystemRunning then
      SystemRunning = true
      SystemPid = pid
   end

   -- Create the dedicated environment and the moonagents_ table
   local env = CopyTable(ENV_TEMPLATE)
   env.moonagents_ = {}
   ENV[pid] = env
   env.self_ = pid
   env.parent_ = pid == SystemPid and 0 or self_ -- we still are in the parent's env
   env.moonagents_.names = {}
   env.moonagents_.children = array()

   local penv = pid~=SystemPid and ENV[env.parent_] or false -- parent agent's _ENV
   -- note that the system agent is contained in pid=0, that has no moonagents_ table

   if isprocedure then -- in this case pid can not be SystemPid, so penv~=nil
      if not name then name = format("procedure%d", pid) end
      env.name_ = name
      if moonagents_.procedure ~= nil then bug() end
      penv.moonagents_.procedure = pid
      penv.moonagents_.atreturn = atreturn
      env.caller_ = penv.caller_ or penv.self_ -- original caller
      env.moonagents_.inputpriority = penv.moonagents_.inputpriority
   else
      env.caller_ = nil
      if not name then name = format("agent%d", pid) end
      env.name_ = name
      env.moonagents_.inputpriority = {}   
   end

   if pid~=SystemPid then
      if penv.moonagents_.names[env.name_] ~= nil then 
         ENV[pid] = nil
         error(format("duplicated agent name '%s'", env.name_))
      end
      -- Insert in name-to-pid map of the parent
      penv.moonagents_.names[env.name_] = pid
      -- Insert in parent's list of children
      penv.moonagents_.children:insert(pid)
   end

   env.moonagents_.states = {}
   -- These are created only when (and if) needed:
   -- env.moonagents_.exportedfunc = {}
   -- env.moonagents_.timers = array()
   -- env.moonagents_.saved = fifo()

   --------------------------------------------------------------
   -- Finally, switch to the new agent and execute the script and the start transition
   SwitchTo(pid) -- _ENV = env

   -- Enable the creation of timers
   if not caller_ then CanCreateTimers = true end

   -- Load the script
   local ld, errmsg = SearchScript(script)
   if not ld then goto failure end

   if trace_on then
      Trace("starting %s '%s' (%s, parent %d)", isprocedure and "procedure" or "agent", 
         name_, ld.fullname, parent_)
   end

   -- Execute the script
   state_ = Startup -- the script should change this with a next_state() or a stop()
   ld.loader(_ENV) 

   -- Rien ne va plus for timer creation
   CanCreateTimers = false

   -- Execute the start transition
   if not moonagents_.startfunc then
      errmsg = format("missing start_transition() in script '%s'", ld.fullname)
      goto failure
   end

   if trace_on then Trace("start transition") end
   moonagents_.startfunc(...)

   if state_ == Startup then
      errmsg = format("missing first next_state() in script '%s'", ld.fullname)
      goto failure
   end

   ::failure::
   if errmsg and pid~=SystemPid then moonagents_for_scripts.stop() end
   SwitchBack()
   --------------------------------------------------------------
   if errmsg then error(errmsg) end
   return pid
end

--=============================================================================
-- Agent termination
--=============================================================================

local function Release() -- release all agents in the release list
   local pid = ReleaseQueue:pop()
   while pid do
      if trace_on then Trace("releasing agent %d", pid) end
      ENV[pid]=nil
      if pid == SystemPid then -- the system agent was released
         SystemRunning = false 
         if trace_on then Trace("system stops") end
      end
      pid = ReleaseQueue:pop()
   end
   if not SystemRunning then ResetSystem() end
   ReleaseFlag = false
end

local function Terminate()
   if trace_on then Trace("terminating") end

   if next(moonagents_.children) then
      bug("terminating agent '%s' pid %d which has children", name_, self_)
   end
   moonagents_.names = nil
   moonagents_.children = nil

   -- Discard all saved signals
   moonagents_.saved = nil

   -- Delete all timers
   if moonagents_.timers then
      for _, tid in ipairs(moonagents_.timers) do TimerDelete(tid) end
      moonagents_.timers = nil
   end

   -- Remove list of exported functions
   moonagents_.exportedfunc = nil

   -- Remove from parent's children list and name-to-pid map
   local penv
   if self_ == SystemPid then
      penv = false
   else
      penv = ENV[parent_]
      penv.moonagents_.names[name_] = nil
      penv.moonagents_.children:remove(self_)
   end

   -- Call the finalizer, if any
   if moonagents_.atstopfunc then moonagents_.atstopfunc() end
   moonagents_ = nil

   -- Eventually release the agent entry. Any signal already scheduled to this
   -- pid will be discarded by the dispatcher.
   ReleaseQueue:push(self_)
   ReleaseFlag = true -- we keep a flag instead of using :count() because it's used in trigger()
-- ENV[self_]=nil -- notice that _ENV still references it

   -- if parent is stopping, and this was its last child, then free the parent also
   if penv and penv.state_ == nil and not next(penv.moonagents_.children) then
      SwitchTo(penv.self_)
      Terminate()
      SwitchBack()
   end
end

--===========================================================================================
-- Sockets
--===========================================================================================

local NO_SOCKET_SELECT = function()
   error("socket.select() is not available on this system")
end

local socket_select = NO_SOCKET_SELECT

local function LoadSocketSelect()
   -- Require sockets, if available
   if socket_select ~= NO_SOCKET_SELECT then return end -- already loaded
   local ok, socket = pcall(require, "socket")
   if not ok then NO_SOCKET_SELECT() end
   socket_select = socket.select
end

local RdSet = array() -- sockets waiting for data to read
local WrSet = array() -- sockets waiting to perform a non blocking write
-- RdSet and WrSet contain either LuaSocket sockets or objects of compatible types.
-- The info associated with each socket in the array() is info = { callback, pid },
-- where pid identifies agent that registered the socket (may be the application)
-- and callback is a a user defined function that is called whenever the socket is
-- ready for a reading or for writeing, passing it the socket itself.

-- 'mode' = "r" or "w"
local function SocketAdd(socket, mode, callback)
   LoadSocketSelect()
   if type(mode)~='string' or (mode~="r" and mode~="w") then error("missing or invalid mode") end
   if type(callback)~='function' then error("missing or invalid callback") end
   local pid = self_ or 0
   local set = mode =="r" and RdSet or WrSet
   socket:settimeout(0) -- make the socket non-blocking
   set:insert(socket, { callback, pid })
   if trace_on then
      Trace("socket_add '%s' (%s, %s)",tostring(socket), mode=='r' and "read" or "write",
            tostring(callback))
   end
   return true
end

local function SocketRemove(socket, mode)
   if type(mode)~='string' or (mode~="r" and mode~="w") then error("missing or invalid mode") end
   local set = mode =="r" and RdSet or WrSet
   local info = set:info(socket)
   if not info then return nil end
   set:remove(socket)
   if trace_on then
      Trace("socket_remove '%s' (%s)",tostring(socket), mode=='r' and "read" or "write")
   end
end

local function DoSocketCallbacks(fdset, dbset)
   for _,socket in ipairs(fdset) do
      local info = RdSet:info(socket)
      if not info then return end -- wtf?
      local callback, pid = table_unpack(info)
      if trace_on then
         Trace("socket '%s' ready for %s",tostring(socket), dbset==RdSet and "read" or "write")
      end
      if pid == 0 then -- socket owned by the application
         callback(socket)
      else -- execute the callback in the owner's _ENV
         if SwitchTo(pid, true) then
            callback(socket)
            SwitchBack()
         else -- pid may have terminated without closing the socket
            if trace_on then Trace("orphan socket ("..tostring(socket)..", pid "..pid..")") end
            socket:close()
            dbset:remove(socket) -- dbset is RdSet or WrSet
         end
      end
   end
end

--=============================================================================
-- Schedulers and dispatcher
--=============================================================================

-- Format of entries inserted in schedulers:
-- { signal, sender, dstpid, sendime, [expiry = NEVER], [istimer] }
--     1       2        3      4           5              6

local function OnBehalfOf(pid)
-- Returns the pid of the innermost nested procedure
   local dstpid = ENV[pid].moonagents_.procedure
   if not dstpid then return pid end
   return OnBehalfOf(dstpid)
end

--xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
local function Dispatch(sig, sender, pid, sendtime, expiry, istimer, redirected)
--xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
-- redirected = true if sig has already made at least one round in this function
   local expiry = expiry or NEVER
   local istimer = istimer or false
   if not SwitchTo(pid, true) then -- Unknown destination (may have stopped, who knows?).
      if trace_on then
         Trace("signal '%s' %d->%d discarded (unknown destination)", sig[1], sender, pid)
      end
      return
   end

   if state_ == nil then -- Destination is in 'stopping' condition (has children still active).
      if trace_on then
         Trace("signal '%s' %d->%d discarded (destination is stopping)", sig[1], sender, pid)
      end
      SwitchBack()
      return
   end

   if istimer and not redirected then
      -- (if the signal is redirected this check has already been done for it)
      if timers_discard(sender) then
         -- The timer that caused this signal was stopped after the signal was sent.
         if trace_on then Trace("signal '%s' %d->%d discarded (timer stopped)", sig[1], sender, pid) end
         SwitchBack()
         return
      end   
   end

   if moonagents_.procedure then -- Redirect the signal to the innermost nested procedure.
      local dstpid = OnBehalfOf(pid) -- need to save this before SwitchBack...
      if trace_on then
         Trace("signal '%s' %d->%d redirected to %d (procedure)",sig[1],sender,pid,dstpid)
      end
      SwitchBack()
      Dispatch(sig, sender, dstpid, sendtime, expiry, istimer, true) 
      return
   end

   -- Set the relevant special variables:
   signal_ = sig
   signame_ = sig[1]
   sender_ = sender
   sendtime_ = sendtime
   exptime_ = expiry
   istimer_ = istimer

   -- Search for the proper transition for 'signame' in the current state:
   local func = nil
   local t = moonagents_.states[state_]
   if t then func = t[signame_] or t[Asterisk] end
   if not func then -- try with default state
      t = moonagents_.states[moonagents_.defstate]
      if t then func = t[signame_] or t[Asterisk] end
   end

   recvtime_ = now()
   if recvtime_ > expiry then -- time-triggered signal arrived too late, sorry
      if trace_on then
         Trace("signal '%s' %d->%d discarded (stale, expired at %f)", sig[1], sender, pid, expiry)
      end
   else -- execute transition, or discard if empty transition
      if trace_on then
         Trace("signal '%s' from %s%d in state '%s' (%s)", signame_, istimer and "timer " or "",
               sender_, state_, func and tostring(func) or "empty transition")
      end
      if func then func() end
   end

   -- Clear the special variables, since they are related only to this signal:
   signal_, signame_, sender_, sendtime_, recvtime_, exptime_, istimer_= nil

   SwitchBack()
end

local function FlushScheduler(sched)
   local s = sched:pop()
   while s do
      -- local ts = now()
      Dispatch(table_unpack(s))
      -- if trace_on then Trace("exec time = %f", since(ts)) end
      s = sched:pop()
   end
end

--=============================================================================
-- Trigger
--=============================================================================

local function Trigger(canblock)
   if not SystemRunning then return nil end

   -- Schedule all time-triggered signals (if any)
   local s = tts_pop()
   while s do
      s[4] = now() -- adjust 'sendtime'
      PrioSchedulers[1]:push(s) -- highest priority 
      PrioSignals = PrioSignals + 1
      s = tts_pop()
   end

   -- Check for timer expiries (may schedule signals)
   timers_trigger()

   -- Dispatch all signals scheduled up to now. Any newly scheduled signal
   -- from now on will be dispatched at the next trigger.
   local norm, prio = NormSignals>0, PrioSignals>0
   if norm or prio then
      -- Swap schedulers, so to dispatch only signals scheduled up to now.
      Scheduler, Scheduler1 = Scheduler1, Scheduler
      PrioSchedulers, PrioSchedulers1 = PrioSchedulers1, PrioSchedulers
      NormSignals, PrioSignals = 0, 0
      -- Flush schedulers, from highest to lowest:
      if prio then for _, sched in ipairs(PrioSchedulers1) do FlushScheduler(sched) end end
      if norm then FlushScheduler(Scheduler1) end
   end

   -- See if any monitored socket is ready, and execute its callback.
   if #RdSet > 0 or #WrSet > 0 then
      local timeout = 0 -- non-blocking
      if canblock and (NormSignals+PrioSignals)==0 then
         -- No signals are scheduled, so there's a chance that we can block on
         -- select() at least for some time
         timeout = min(timers_tnext(), tts_tnext()) - now()
         if timeout < 0 then timeout = 0            -- non-blocking
         elseif timeout == NEVER then timeout = nil -- blocking
         end
      end
      local r, w = socket_select(RdSet, WrSet, timeout)
      -- @@ local r, w, errmsg = socket_select(RdSet, WrSet, timeout)
      --    if errmsg and errmsg ~= "timeout" then error(errmsg)  end
      -- Execute callbacks of sockets that are ready. These also may schedule
      -- signals, that will be dispatched at the next round.
      if r then DoSocketCallbacks(r, RdSet) end
      if w then DoSocketCallbacks(w, WrSet) end
   end

   if ReleaseFlag then Release() end
   return SystemRunning and NormSignals+PrioSignals or nil
end

--=============================================================================
-- Create functions
--=============================================================================

local function Create(name, script,...)
   offspring_ = NewAgent(false, nil, name, script, ...)
   return offspring_
end

local function Procedure(atreturn, name, script, ...)
   -- don't change offspring_ here, because a procedure is not really an agent.
   return NewAgent(true, atreturn, name, script, ...)
end

local function ProcedureReturn(...)
   if trace_on then Trace("procedure_return") end
   local penv = ENV[parent_] -- the caller
   -- move signals from procedure's saved queue to caller's saved queue
   if moonagents_.saved then
      local s = moonagents_.saved:pop()
      while s do
         s[3] = penv.self_
         if not penv.moonagents_.saved then penv.moonagents_.saved = fifo() end
         penv.moonagents_.saved:push(s)
         s = moonagents_.saved:pop()
      end
   end
   ---------------------------------------------------------------
   SwitchTo(parent_) --caller
   local atreturn = moonagents_.atreturn
   moonagents_.procedure = nil
   moonagents_.atreturn = nil
   if atreturn then
      if type(atreturn) == 'function' then
         atreturn(...)
      elseif type(atreturn) == 'string' then
         moonagents_for_scripts.next_state(atreturn)
      end
   end
   SwitchBack()
   ---------------------------------------------------------------
   state_ = nil -- mark as 'stopping'
   if not next(moonagents_.children) then Terminate() end
end

--=============================================================================
-- State machine definition functions
--=============================================================================

local function StartTransition(func) 
   if type(func)~='function' then error("missing or invalid function") end
   moonagents_.startfunc = func
   if trace_on then Trace("start_transition (%s)", tostring(func)) end
end

local function Transition(state, signame, func)
   if type(state)~='string' then error("missing or invalid state") end
   if type(signame)~='string' then error("missing or invalid signal name") end
   if type(func)~='function' then error("missing or invalid function") end
   if moonagents_.states[state]==nil then
      moonagents_.states[state] = {} -- create state
   end
   moonagents_.states[state][signame] = func
   if trace_on then
      Trace("transition for signal '%s' in state '%s' (%s)", signame, state, tostring(func))
   end
end

local function DefaultState(state)
   if type(state)~='string' or state==Startup or state==Dash then error("missing or invalid state") end
   if moonagents_.states[state]==nil then 
      moonagents_.states[state]={} -- create state
   end
   moonagents_.defstate = state
   if trace_on then Trace("default_state '%s'", state) end
end   

local function NextState(state) 
   if type(state)~='string' or state==Startup then error("missing or invalid state") end
   if state==Dash then return end -- dash state (i.e. keep the old state)
   if not state_ then error("cannot change state (agent is terminating") end
   local oldstate = state_
   state_ = state
   if trace_on then Trace("next_state '%s' -> '%s'", oldstate, state_) end
   if oldstate ~= state_ then moonagents_for_scripts.restore() end
end


local function Stop(atstopfunc)
   if caller_~=nil then error("procedures shall use procedure_return() instead of stop()") end
   if trace_on then Trace("stop") end
   if not state_ then return end -- already stopping
   state_ = nil -- mark as 'stopping'
   if atstopfunc then
      if type(atstopfunc)~='function' then error("invalid finalizer") end
      moonagents_.atstopfunc = atstopfunc
   end 
   if not next(moonagents_.children) then
      Terminate()
   end
   -- When an agent stop()s, it enters a 'stopping condition' (cfr. Z.101/9)
   -- and it remains in that condition until all its children have terminated.
   -- Only at that point it terminates too.
   -- While in the stopping condition, the agent does not receive signals,
   -- but it remains available for remote synchronous calls (remote_call())
   -- from other agents.
end

--=============================================================================
-- Send/save/restore signals
--=============================================================================

local ReceiveCallback = nil

local function SetReceiveCallback(func)
   if type(func)~='function' and func~=nil then error("invalid callback") end
   ReceiveCallback = func
end

local function SendOut(sig)
   if type(sig)~='table' then error("missing or invalid signal") end
   local srcpid =  caller_ or self_
   if trace_on then Trace("send_out '%s' %d->0", sig[1], srcpid) end
   if ReceiveCallback then ReceiveCallback(sig, srcpid) end
end

local function Send(sig, dstpid, priority)
   if type(sig)~='table' then error("missing or invalid signal") end
   if dstpid==nil or tointeger(dstpid)~=dstpid then error("missing or invalid destination pid") end
   if tointeger(priority)~=priority then error("invalid priority") end
   if dstpid == 0 then return SendOut(sig) end
   local env = ENV[dstpid] -- destination agent
   priority = ( env and env.moonagents_.inputpriority[sig[1]] ) or priority
   if priority and (( priority > PrioLevels ) or ( priority < 1 )) then 
      priority = nil -- normal priority
   end
   local srcpid =  caller_ or self_
   local sendtime = now()
   if not priority then
      Scheduler:push({ sig, srcpid, dstpid, sendtime })
      NormSignals = NormSignals + 1
   else
      PrioSchedulers[priority]:push({ sig, srcpid, dstpid, sendtime })
      PrioSignals = PrioSignals + 1
   end
   if trace_on then
      if priority then
         Trace("send '%s' %d->%d (priority %d)", sig[1], srcpid, dstpid, priority)
      else
         Trace("send '%s' %d->%d", sig[1], srcpid, dstpid)
      end
   end
   return sendtime
end

local function InputPriority(signame, priority)
   if type(signame)~='string' then error("missing or invalid signal name") end
   if tointeger(priority)~=priority then error("invalid priority") end
   moonagents_.inputpriority[signame] = priority
   if trace_on then
      Trace("input_priority for '%s' signals is set to %s", 
         signame, priority and tostring(priority) or "normal")
   end
end

local function SendAt(sig, dstpid, at, maxdelay)
-- Time-Triggered Signals (aka "Real-time signalling", but there is no real 'real-time' here)
   if type(sig)~='table' then error("missing or invalid signal") end
   if dstpid==nil or tointeger(dstpid)~=dstpid then error("invalid destination pid") end
   if at==nil or tonumber(at)~=at then error("missing or invalid delivery time (at)") end
   if tonumber(maxdelay)~=maxdelay then error("invalid maxdelay") end
   local srcpid =  caller_ or self_ or 0
   local expiry = maxdelay and at + maxdelay or NEVER -- when sig must be considered stale
   if trace_on then
      Trace("send_at '%s' %d->%d at %f (expires at %f)", sig[1], srcpid, dstpid, at, expiry)
   end
   tts_send({ sig, srcpid, dstpid, at, expiry }, at)
end

--@@ "continuous signals" should be implementable with priority signals
 
local function Save()
   if trace_on then Trace("saved signal '%s' from %d", signal_[1], sender_) end
   if not moonagents_.saved then moonagents_.saved = fifo() end
   moonagents_.saved:push({ signal_, sender_, self_, sendime_, exptime_, istimer_ })
end

local function Restore()
-- re-schedules all saved signals for the current agent
   if not moonagents_.saved then return end 
   local s = moonagents_.saved:pop()
   while s do
      if trace_on then Trace("restored signal '%s' from %d", s[1][1], s[2]) end
      PrioSchedulers[1]:push(s) -- highest priority 
      PrioSignals = PrioSignals + 1
      s = moonagents_.saved:pop()
   end
end

--=============================================================================
-- Synchronous remote function call
--=============================================================================

local function ExportFunction(funcname, func)
   if type(funcname)~='string' then error("missing or invalid function name") end
   if func~=nil and type(func)~='function' then error("invalid function") end
   if func then
      if trace_on then Trace("export_function '%s' (%s)", funcname, func) end
   else
      if trace_on then Trace("export_function '%s' (revoked)", funcname) end
   end
   if not moonagents_.exportedfunc then moonagents_.exportedfunc = {} end
   moonagents_.exportedfunc[funcname]=func
end

local function RemoteCall(pid, funcname, ...)
-- Note: this is a non-SDL construct: it is not a SDL 'remote procedure'(Z.102/10.5),
-- Such a procedure has states and a different mechanism, which can be implemented
-- using the basic SDL constructs.
   if type(funcname)~='string' then error("missing or invalid function name") end
   if trace_on then Trace("remote_call %s() on pid %d", funcname, pid) end
   if not SwitchTo(pid) then
      error(format("remote_call on unknown pid %d from pid %d", pid, self_))
   end
   local func = moonagents_.exportedfunc and moonagents_.exportedfunc[funcname] or nil
   if not func then
      error(format("remote_call on unknown function '%s' from pid %d", funcname, pid))
   end
   local retval = { func(...) }
   SwitchBack()
   return table_unpack(retval)
end

--=============================================================================
-- Configuration
--=============================================================================

local function SetEnvTemplate(env)
   if SystemRunning then error( "cannot set _ENV template while the system is running") end
   if type(env)~='table' then error("invalid argument") end
   ENV_TEMPLATE = CopyTable(env)
   ENV_TEMPLATE.moonagents = moonagents_for_scripts -- all processes need this
end

local function SetPriorityLevels(levels)
   if SystemRunning then error("cannot set priority levels while the system is running") end
   PrioLevels = levels or 1
   if tointeger(PrioLevels)~=PrioLevels or PrioLevels<=0 or PrioLevels>MAX_PRIO_LEVELS then
      error("invalid number of priority levels")
   end
   Log("number of priority levels set to %u", PrioLevels)
end

local function SetSpecialValue(name, value)
   if SystemRunning then error("cannot set special values while the system is running") end
   if type(name)~='string' or not Special[name] then error("missing or invalid name") end
   if type(value)~='string' then error("missing or invalid value") end
   if name == 'startup' then Startup = value
   elseif name == 'dash' then Dash = value
   elseif name == 'asterisk' then Asterisk = value
   end
   Log("special values: startup='%s', dash='%s' asterisk='%s'", Startup, Dash, Asterisk)
end

local function CreateSystem(name, script, ...)
   if SystemRunning then error("cannot create system while the system is running") end
   if name~=nil and type(name)~='string' then error("invalid name") end
   if type(script)~='string' then error("missing or invalid script") end 
   self_ = 0          -- I'm the application
   ENV[self_] = _ENV  -- and this is my environment

   if trace_on then Trace("system starts") end
   -- create the schedulers
   Scheduler = fifo()
   Scheduler1 = fifo()
   PrioSchedulers, PrioSchedulers1 = {}, {}
   for i = 1, PrioLevels do
      PrioSchedulers[i] = fifo(PrioLevels)
      PrioSchedulers1[i] = fifo(PrioLevels)
   end

   -- prepare the template environment
   if not ENV_TEMPLATE then SetEnvTemplate(_ENV) end

   -- configure the timers module
   timers_init(TimersCallback)

   -- Eventually create the first agent (pid=1)
   return NewAgent(false, nil, name, script, ...)
end

--=============================================================================
-- Agent information
--=============================================================================

local function PidOf(name, rpid)
   local rpid = rpid or 0
   if tointeger(rpid)~=rpid then error("invalid rpid") end
   local names = Split(name, '.')
   if #names == 0 then error("invalid name") end
   for _, n in ipairs(names) do
      if rpid==0 then
         -- the system agent is the only child of rpid=0:
         if n == ENV[SystemPid].name_ then rpid = SystemPid else error("unknown name") end
      else
         local env = ENV[rpid]
         if not env then error("invalid rpid") end
         rpid = env.moonagents_.names[n]
      end
      if not rpid then error("unknown name") end -- not found
   end
   return rpid
end

local function ParentOf(pid)
   if pid==nil or tointeger(pid)~=pid or pid == 0 then error("invalid pid") end
   local env = ENV[pid]
   if not env then error("invalid pid") end
   return env.parent_
end

local function LocalNameOf(pid) -- pid > 0
   local env = ENV[pid]
   if not env then error("invalid pid") end
   return env.name_
end

local function NameOf(pid, rpid)
   local rpid = rpid or 0
   if pid==nil or tointeger(pid)~=pid or pid == 0 then error("invalid pid") end
   if tointeger(rpid)~=rpid then error("invalid pid") end
   local names = { LocalNameOf(pid) }
   local found = false
   -- Get the names of the parents up to rpid or to the application:
   while pid ~= 0 do
      pid = ParentOf(pid)
      if pid == rpid then found = true break end
      names[#names+1] = LocalNameOf(pid)
   end
   if not found then error("unknown pid") end
   -- Reverse the table and concatenate:
   local fullname= {}
   for i=#names, 1, -1 do fullname[#fullname+1]=names[i] end
   return table_concat(fullname, '.')
end

local function StateOf(pid)
   if pid==nil or tointeger(pid)~=pid or pid == 0 then error("invalid pid") end
   local env = ENV[pid]
   if not env then error("invalid pid") end
   return env.state_
end

local function ChildrenOf(pid)
   if pid==nil or tointeger(pid)~=pid or pid == 0 then error("invalid pid") end
   local env = ENV[pid]
   if not env then error("invalid pid") end
   return { table_unpack(env.moonagents_.children) }
end

local function TimersOf(pid)
   if pid==nil or tointeger(pid)~=pid or pid == 0 then error("invalid pid") end
   local env = ENV[pid]
   if not env then error("invalid pid") end
   if not env.moonagents_.timers then return {} end
   return { table_unpack(env.moonagents_.timers) }
end

local function Tree(pid, islast, indent, s)
   local pid = pid or self_
   local islast = islast == nil and true or islast
   local s = s or "\n" -- destination string
   local indent = indent or ""
   if pid==SystemPid then
      prefix = ""
   elseif islast then
      prefix = indent .. "└─"
      indent = indent .. "  "
   else
      prefix = indent .. "├─"
      indent = indent .. "│ " 
   end
   local env = ENV[pid]
   if not env then error("invalid pid") end
   s = s .. format(
            "%s[%d] %s (%s) %d/{%s}/{%s} in state %s\n",
            prefix, pid, env.name_, env.caller_ and "procedure" or "agent", env.parent_,
            next(env.moonagents_.children) and table_concat(env.moonagents_.children, ",") or "",
            env.moonagents_.timers and next(env.moonagents_.timers) and 
               table_concat(env.moonagents_.timers, ",") or "", env.state_)
   -- find last descendant
   local last
   for _, cpid in ipairs(env.moonagents_.children) do last = cpid end
   -- print all descendants
   for _, cpid in ipairs(env.moonagents_.children) do 
       s = Tree(cpid, cpid==last, indent, s)
   end
   return s
end

local function TreeOf(pid)
   if pid==nil or tointeger(pid)~=pid or pid == 0 then error("invalid pid") end
   return "\n[pid] name (type) parent/{children}/{timers}"..Tree(pid)
end


--=============================================================================
-- Utilities
--=============================================================================

local function GlobalFunctions(prefix)
   local prefix = prefix or ""
   for k, v in pairs(_ENV.moonagents) do
      if type(v) == 'function' then _ENV[prefix..k] = v end
   end
end

local set_text_style = moonagents.set_text_style

local function StyleWrite(style, ...)
   set_text_style(style)
   io.write(...)
   set_text_style()
end

-- The moonagents table as seen by the application --------------------------------
-- This function should be used only when the system is not running
moonagents.set_priority_levels = SetPriorityLevels
moonagents.set_env_template = SetEnvTemplate
moonagents.set_special_values = SetSpecialValue
moonagents.create_system = CreateSystem

-- This functions can be used always:
moonagents.set_log_preamble = SetLogPreamble
moonagents.trigger = Trigger
moonagents.reset = ResetSystem
moonagents.set_receive_callback = SetReceiveCallback
moonagents.socket_add = SocketAdd
moonagents.socket_remove = SocketRemove
moonagents.send = Send
moonagents.send_at = SendAt
moonagents.remote_call = RemoteCall
moonagents.log_open = LogOpen
moonagents.log_enable = LogEnable
moonagents.log_close = LogClose
moonagents.log_file = LogFile
moonagents.log_flush = LogFlush
moonagents.log = Log
moonagents.log_print = LogPrint
moonagents.trace_enable = TraceEnable
moonagents.parent_of = ParentOf
moonagents.style_write = StyleWrite

-- These functions should be used only when the system is running:
moonagents.pid_of = PidOf
moonagents.name_of = NameOf
moonagents.state_of = StateOf
moonagents.tree_of = TreeOf
moonagents.children_of = ChildrenOf
moonagents.timers_of = TimersOf


-- The moonagents table as seen by the scripts ------------------------------------
moonagents_for_scripts._VERSION = moonagents._VERSION
moonagents_for_scripts.global_functions = GlobalFunctions
moonagents_for_scripts.now = now
moonagents_for_scripts.since = since
moonagents_for_scripts.create = Create
moonagents_for_scripts.start_transition = StartTransition
moonagents_for_scripts.transition = Transition
moonagents_for_scripts.default_state = DefaultState
moonagents_for_scripts.next_state = NextState
moonagents_for_scripts.stop = Stop
moonagents_for_scripts.procedure = Procedure
moonagents_for_scripts.procedure_return = ProcedureReturn
moonagents_for_scripts.export_function = ExportFunction
moonagents_for_scripts.remote_call = RemoteCall
moonagents_for_scripts.send = Send
moonagents_for_scripts.send_out = SendOut
moonagents_for_scripts.send_at = SendAt
moonagents_for_scripts.timer = Timer
moonagents_for_scripts.timer_modify = TimerModify
moonagents_for_scripts.timer_start = TimerStart
moonagents_for_scripts.timer_stop = TimerStop
moonagents_for_scripts.timer_running = TimerRunning
moonagents_for_scripts.input_priority = InputPriority
moonagents_for_scripts.save = Save
moonagents_for_scripts.restore = Restore
moonagents_for_scripts.socket_add = SocketAdd
moonagents_for_scripts.socket_remove = SocketRemove
moonagents_for_scripts.pid_of = PidOf
moonagents_for_scripts.name_of = NameOf
moonagents_for_scripts.state_of = StateOf
moonagents_for_scripts.tree_of = TreeOf
moonagents_for_scripts.children_of = ChildrenOf
moonagents_for_scripts.timers_of = TimersOf
moonagents_for_scripts.log_file = LogFile
moonagents_for_scripts.log_enable = LogEnable
moonagents_for_scripts.log_open = LogOpen
moonagents_for_scripts.log_close = LogClose
moonagents_for_scripts.log_flush = LogFlush
moonagents_for_scripts.log = Log
moonagents_for_scripts.log_print = LogPrint
moonagents_for_scripts.trace_enable = TraceEnable
moonagents_for_scripts.parent_of = ParentOf
moonagents_for_scripts.set_text_style = moonagents.set_text_style
moonagents_for_scripts.style_write = StyleWrite

