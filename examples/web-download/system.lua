-- System agent: system.lua

moonagents.global_functions()

local function Start(host, pages)
   log_print("%s: Creating agents", name_)
   for _,file in ipairs(pages) do
      create(nil,"download", host, file)
   end
   stop()
end

start_transition(Start)

