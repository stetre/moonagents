/* The MIT License (MIT)
 *
 * Copyright (c) 2019 Stefano Trettel
 *
 * Software repository: MoonAgents, https://github.com/stetre/moonagents
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#include "internal.h"

static lua_State *moonagents_L = NULL;

static void AtExit(void)
    {
    if(moonagents_L)
        {
        enums_free_all(moonagents_L);
        moonagents_L = NULL;
        }
    }
 
static int AddVersion(lua_State *L)
    {
    lua_pushstring(L, "_VERSION");
    lua_pushstring(L, "MoonAgents "MOONAGENTS_VERSION);
    lua_settable(L, -3);
    return 0;
    }


int luaopen_moonagents(lua_State *L)
/* Lua calls this function to load the module */
    {
    moonagents_L = L;

    moonagents_utils_init(L);
    atexit(AtExit);

    lua_newtable(L); /* the moonagents table */

    AddVersion(L);
    moonagents_open_enums(L);
    moonagents_open_utils(L);
    moonagents_open_timers(L);
    moonagents_open_tts(L);

    /* Add functions implemented in Lua */
    lua_pushvalue(L, -1); lua_setglobal(L, "moonagents");
    if(luaL_dostring(L, "require('moonagents.engine')") != 0) lua_error(L);
    lua_pushnil(L);  lua_setglobal(L, "moonagents");

    return 1;
    }

