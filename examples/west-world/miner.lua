-- Miner agent: miner.lua

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

local ComfortLevel = 5 -- the amount of gold a miner must have before he feels he can go home
local MaxNuggets = 3 -- the amount of nuggets a miner can carry
local ThirstLevel = 5 -- above this value a miner is thirsty
local TirednessThreshold = 5 -- above this value a miner is sleepy

local Wife -- pid of wife agent
local Location = "shack" -- where he is
local GoldCarried = 0 -- how many nuggets the miner has in his pockets
local Wealth = 0 -- money in bank
local Thirst = 0 --the higher the value, the thirstier the miner
local Fatigue = 0 --the higher the value, the more tired the miner

local function PocketsFull() return GoldCarried >= MaxNuggets end
local function Thirsty() return Thirst >= ThirstLevel end
local function Fatigued() return Fatigue > TirednessThreshold end
local function BuyAndDrinkAWhiskey() Thirst = 0; Wealth = Wealth - 2 end

local function Say(...)
   set_text_style({"red"})
   print(name_..": "..string.format(...))
   set_text_style()
end

--------------------------------------------------------------------------
--  In this state the miner will walk to a goldmine and pick up a nugget
--  of gold. If the miner already has a nugget of gold he'll change state
--  to VisitBankAndDepositGold. If he gets thirsty he'll change state
--  to QuenchThirst

Enter["EnterMineAndDigForNugget"] = function()
   -- If the miner is not already located at the goldmine, he must
   -- change location to the gold mine
   if Location ~= 'goldmine' then
      Say("Walkin' to the goldmine")
      Location = 'goldmine'
   end
end

Execute["EnterMineAndDigForNugget"] = function()
   -- Now the miner is at the goldmine he digs for gold until he
   -- is carrying in excess of MaxNuggets. If he gets thirsty during
   -- his digging he packs up work for a while and changes state to
   -- go to the saloon for a whiskey.
   GoldCarried = GoldCarried + 1
   Fatigue = Fatigue + 1
   Say("Pickin' up a nugget")
   --if enough gold mined, go and put it in the bank
   if PocketsFull() then next_state("VisitBankAndDepositGold") end
   if Thirsty() then next_state("QuenchThirst") end
end

Exit["EnterMineAndDigForNugget"] = function()
   Say("Ah'm leavin' the goldmine with mah pockets full o' sweet gold")
end

--------------------------------------------------------------------------
--  Entity will go to a bank and deposit any nuggets he is carrying. If the 
--  miner is subsequently wealthy enough he'll walk home, otherwise he'll
--  keep going to get more gold

Enter["VisitBankAndDepositGold"] = function()
   --on entry the miner makes sure he is located at the bank
   if Location ~= 'bank' then
      Say("Goin' to the bank. Yes siree")
      Location = 'bank'
   end
end

Execute["VisitBankAndDepositGold"] = function()
   --deposit the gold
   Wealth = Wealth + GoldCarried
   GoldCarried = 0
   Say("Depositing gold. Total savings now: %d", Wealth)
   --wealthy enough to have a well earned rest?
   if Wealth >= ComfortLevel then
      Say("WooHoo! Rich enough for now. Back home to mah li'lle lady")
      next_state("GoHomeAndSleepTilRested")
   else --otherwise get more gold
      next_state("EnterMineAndDigForNugget")
   end
end

Exit["VisitBankAndDepositGold"] = function()
   Say("Leavin' the bank")
end

--------------------------------------------------------------------------
--  miner will go home and sleep until his fatigue is decreased sufficiently

Enter["GoHomeAndSleepTilRested"] = function()
   if Location ~= 'shack' then
      Say("Walkin' home")
      Location = 'shack'
      --let the wife know I'm home
      send({"HI_HONEY_IM_HOME"}, Wife)
   end
end

Execute["GoHomeAndSleepTilRested"] = function()
   --if miner is not fatigued start to dig for nuggets again.
   if not Fatigued() then
      Say("All mah fatigue has drained away. Time to find more gold!")
      next_state("EnterMineAndDigForNugget")
   else 
      --sleep
      Fatigue = Fatigue - 1
      Say("ZZZZ... ")
   end
end

local function GoHomeAndSleepTilRested_StewReady()
   Say("Okay Hun, ahm a comin'!")
   next_state("EatStew")
end

--------------------------------------------------------------------------
--  miner changes location to the saloon and keeps buying Whiskey until
--  his thirst is quenched. When satisfied he returns to the goldmine
--  and resumes his quest for nuggets.

Enter["QuenchThirst"] = function()
   if Location ~= 'saloon' then
      Location = 'saloon'
      Say("Boy, ah sure is thusty! Walking to the saloon")
   end
end

Execute["QuenchThirst"] = function()
   BuyAndDrinkAWhiskey()
   Say("That's mighty fine sippin' liquer")
   next_state("EnterMineAndDigForNugget")
end

Exit["QuenchThirst"] = function()
   Say("Leaving the saloon, feelin' good")
end

--------------------------------------------------------------------------
--  this is implemented as a state blip. The miner eats the stew, gives
--  Elsa some compliments and then returns to his previous state

Enter["EatStew"] = function()
   Say("Smells Reaaal goood Elsa!")
end

Execute["EatStew"] = function()
   Say("Tastes real good too!")
   next_state(PrevState)
end

Exit["EatStew"] = function()
   Say("Thankya li'lle lady. Ah better get back to whatever ah wuz doin'")
end

--------------------------------------------------------------------------

local function Start()
   -- store wifey's pid
   Wife = signal_[2]
   next_state("GoHomeAndSleepTilRested")
end

local function Update()
   Thirst = Thirst + 1
   if Execute[state_] then Execute[state_]() end
end

start_transition(function() next_state("Starting") end)
transition("Starting", "START", Start)
transition("GoHomeAndSleepTilRested", "STEW_READY", GoHomeAndSleepTilRested_StewReady)
transition("Any", "UPDATE", Update)
transition("Any", "STOP", function() stop() end)
default_state("Any")

