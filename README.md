## MoonAgents: Reactive state machines in Lua

MoonAgents is a Lua module for event-driven concurrent programming.

It is designed after the concurrency model of the
[ITU-T Specification and Description Language (SDL)](http://en.wikipedia.org/wiki/Specification_and_Description_Language) and provides functions for the implementation of systems composed of concurrent,
reactive and intercommunicating finite state machines (*'agents'*).

MoonAgents runs on GNU/Linux and on Windows (MSYS2/MinGW) and requires 
[Lua](http://www.lua.org/) (>=5.3).

_Author:_ _[Stefano Trettel](https://www.linkedin.com/in/stetre)_

(_Note: MoonAgents is derived from [LunaSDL](https://github.com/stetre/lunasdl), which it supersedes, and which is now discontinued. The major differences with LunaSDL are listed in the [design notes](./design-notes.md) document.)_

[![Lua logo](./doc/powered-by-lua.gif)](http://www.lua.org/)

#### License

MIT/X11 license (same as Lua). See [LICENSE](./LICENSE).

#### Documentation

See the [Reference Manual](https://stetre.github.io/moonagents/doc/index.html).

#### Getting and installing

Setup the build environment as described [here](https://github.com/stetre/moonlibs), then:

```sh
$ git clone https://github.com/stetre/moonagents
$ cd moonagents
moonagents$ make
moonagents$ sudo make install
```

#### Examples

The example below creates an agent that gives the traditional salute with a little delay
(using a timer) and then stops.

Other examples can be found in the **examples/** directory of this repo.

```lua
-- Hello World application - hello.lua

local moonagents = require("moonagents")

-- Create the system agent, from the script 'agent.lua':
local system = moonagents.create_system("HelloSystem","agent")

-- Enter the event loop:
while moonagents.trigger() do end
```

```lua
-- Agent script - agent.lua

local delay = 1.2 -- seconds
local T = moonagents.timer(delay,"T_EXPIRED")

local function Start()
   print("Please, wait "..delay.." seconds ...")
   moonagents.timer_start(T)
   moonagents.next_state("Waiting")
end

local function TExpired()
   print("... Hello World!")
   moonagents.stop()
end

moonagents.start_transition(Start)
moonagents.transition("Waiting", "T_EXPIRED", TExpired)
```

The script can be executed at the shell prompt with the standard Lua interpreter:

```shell
$ lua hello.lua
```

See the `examples/` directory.

#### See also

* [MoonLibs - Graphics and Audio Lua Libraries](https://github.com/stetre/moonlibs).
