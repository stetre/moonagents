-- Wife agent: wife.lua

moonagents.global_functions()

local Enter, Execute, Exit, PrevState = {}, {}, {}, "?"

local function next_state(state)
   -- Execute the exit function for the old state (if any):
   if Exit[state_] then Exit[state_]() end
   -- Save the old state:
   PrevState = state_
   -- Change state:
   moonagents.next_state(state)
   -- Execute the enter function for the old state (if any):
   if Enter[state_] then Enter[state_]() end
end

-------------------------------------------------------------------------------

local Husband -- pid of husband agent
local Location = "shack" -- where she is
local Cooking = false --is she presently cooking?

local function Say(...)
   set_text_style({"green"})
   print(name_..": "..string.format(...))
   set_text_style()
end

-------------------------------------------------------------------------------

Enter["DoHouseWork"] = function()
   Say("Time to do some more housework!")
end

Execute["DoHouseWork"] = function()
   local val = math.random()
   if val < 1/3 then Say("Moppin' the floor")
   elseif val < 2/3 then Say("Washin' the dishes")
   else Say("Makin' the bed")
   end
end

--------------------------------------------------------------------------

Enter["VisitBathroom"] = function()
   Say("Walkin' to the can. Need to powda mah pretty li'lle nose")
end

Execute["VisitBathroom"] = function()
   Say("Ahhhhhh! Sweet relief!")
   next_state(PrevState)
end

Exit["VisitBathroom"] = function()
   Say("Leavin' the Jon")
end

--------------------------------------------------------------------------

Enter["CookStew"] = function()
   if Cooking then return end
   --if not already cooking put the stew in the oven
   Say("Putting the stew in the oven")
   --send a delayed message myself so that I know when to take the stew out of the oven
   send_at({"STEW_READY"}, self_, now() + 1.5)
   Cooking = true
end

Execute["CookStew"] = function()
   Say("Fussin' over food")
end

Exit["CookStew"] = function()
   Say("Puttin' the stew on the table")
end

local function CookStew_StewReady()
   Say("StewReady! Lets eat")
   --let hubby know the stew is ready
   send({"STEW_READY"}, Husband)
   Cooking = false
   next_state("DoHouseWork")
end

--------------------------------------------------------------------------

local function Any_HiHoneyImHome()
   Say("Hi honey. Let me make you some of mah fine country stew")
   next_state("CookStew")
end

--------------------------------------------------------------------------

local function Start()
   -- store hubby's pid
   Husband = signal_[2]
   next_state("DoHouseWork")
end

local function Update()
   -- 1 in 10 chance of needing the bathroom (provided she is not already there)
   if state_ ~= "VisitBathroom" and math.random() < .1 then
      next_state("VisitBathroom")
   end
   if Execute[state_] then Execute[state_]() end
end

start_transition(function() next_state("Starting") end)
transition("Starting", "START", Start)
transition("CookStew", "STEW_READY", CookStew_StewReady)
transition("Any", "HI_HONEY_IM_HOME", Any_HiHoneyImHome)
transition("Any", "UPDATE", Update)
transition("Any", "STOP", function() stop() end)
default_state("Any")

