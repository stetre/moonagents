
## MoonAgents design notes

_Stefano Trettel, 2019/01/05_

MoonAgents is a streamlined iteration of [LunaSDL](https://github.com/stetre/lunasdl), which it supersedes. Here the major differences:

* The library is now part of the [MoonLibs](https://github.com/stetre/moonlibs) collection,
while LunaSDL was not. I named it "MoonAgents" instead of "MoonSDL" to avoid confusion with the
"Simple DirectMedia Layer", which is more popular than the "Specification and Description Language"
and whose acronym is also SDL.

* It supports almost all LunaSDL features I can think of, except
for the configurable pollfunc to be used instead of socket.select (but this
should not be hard to add, if needed).

* Removed the reactor together with the built-in event loop. Instead, the user
is now provided with a trigger() function that she can use in her own event loop
to trigger the internal scheduler that dispatches signals to agents and manages
timers. This results in a cleaner interface, and allows for easier integration
with other technologies such as graphics and audio libraries.
	
* Unlike LunaSDL which was a pure-Lua module, MoonAgents is a C library. It is still
mainly implemented in Lua, but it is predisposed for 'moving up' the line between Lua
and C, if needed.

* It has its own gettime() function, which is now called now() - consistently
with the companion MoonLibs libraries - and which is implemented in C.
This means that LuaSocket is no more required unless sockets are used, and
that the user is no more required to provide a suitable gettime() function
in case LuaSocket is not available (and, most important, I must no more
go through the pain of documenting the hows and whys).

* Removed the concept of 'starting time'. The SDL system time - given by the
now() function - is now relative to an unspecified point in the past.
Again, this choice is for consistency with the companions MoonLibs libraries.

* LuaSocket is now require()'d only when (and if) the user first attempts to
add a socket to be monitored and a callback to be executed when the socket is
ready. 
The only LuaSocket functions used directly by MoonAgents are socket.select(),
and the settimeout() and close() methods of socket objects.
This makes LuaSocket easily replaceable, if needed (it's not that i dislike LuaSocket,
which is awesome. It's just that I don't like dependencies).

* Renamed and restyled a few functions. In particular, I renamed the timer-related
functions because I find that the names used in the SDL specs which
I stuck to when I wrote LunaSDL - i.e. 'set', 'reset', etc - made the state
machines' code less readable than names like 'timer_start' and 'timer_stop'.

* Clearer separation between the application and the SDL system. Unlike in
LunaSDL, where the application and the system agent were somehow merged
together and both identified by pid=0, now they are two entirely different
entities and the application (pid=0) can exchange signals with the system
agent (pid=1) as well as with any other agent. To handle signals the agents
send to it, the application must now register a receive callback.

* Removed the SDL concept of 'block' (together with the concept of agent 'kind'),
since it added nothing but accidental complexity: if you want an agent to be
just a container, then use it only as a container.

* Removed the concept of 'system return values' and its related mechanism.
To return values to the application, the SDL system (any agent) can now just
send signals to it, and it can do it at any time not only when it stops.

* Removed the kill() function, which is not part of the SDL standard, is
difficult to get right, and is, in the end, superfluous. If a system designer
wants agents to be killable, it must design this capability in their state machines.

* Removed the tagged traces facility. They were expensive and - at least for my taste -
too hard to use to be really useful. Kept the ability to generate internal traces, though.

* The string values reserved to denote the startup and dash states, and the
asterisk input, are now configurable (although I would advise to stick to
the default ones, if one wants agent scripts to be reusable).

* Added functions to control the text style output with ANSI escape codes (works
only on terminals that support them), for quick and dirty text-based applications.

* Shorter and hopefully clearer manual. Removed the descriptions
of the examples because it is meant to be a reference manual, not a tutorial.

* Added a port of the 'West World' example from Mat Buckland's popular book on
game AI. Also added the coroutine implementation of the 'web-download' example
(from Programming in Lua) so to have a comparison at hand.

* Replaced Matt Bianco with The Police in one of the examples (only because
of the language switch from the italian "Luna" to the more international "Moon").

