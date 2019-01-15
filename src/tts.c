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
 
/* Time-triggered signals
 * @@ TODO
 * - replace rb tree with a proper priority queue
 * - pre-allocated pool to avoid Malloc/Free at every signal
 */

#define signal_t struct signal_s
struct signal_s {
    RB_ENTRY(signal_s) Entry;
    uint64_t cnt;   /* signal counter (to provide unique search key based on at) */
    double at;      /* when the signal must be sent */
    int ref;        /* reference on Lua registry for the signal (a table) */
};

static int cmp(signal_t *signal1, signal_t *signal2) 
    {
    if(signal1->at < signal2->at) return -1;
    if(signal1->at > signal2->at) return 1;
    return signal1->cnt < signal2->cnt ? -1 : signal1->cnt > signal2->cnt;
    }

static RB_HEAD(Tree, signal_s) Head = RB_INITIALIZER(&Head);
RB_PROTOTYPE_STATIC(Tree, signal_s, Entry, cmp) 
RB_GENERATE_STATIC(Tree, signal_s, Entry, cmp) 

static signal_t *Remove(signal_t *signal) { return RB_REMOVE(Tree, &Head, signal); }
static signal_t *Insert(signal_t *signal) { return RB_INSERT(Tree, &Head, signal); }
#if 0
static signal_t *Search(uint32_t cnt, double at)
    { signal_t tmp; tmp.at = at; tmp.cnt = cnt; return RB_FIND(Tree, &Head, &tmp); }
#endif
static signal_t *First(void)
    { signal_t tmp; tmp.at = 0; tmp.cnt = 0.0; return RB_NFIND(Tree, &Head, &tmp); }
#if 0
static signal_t *Next(signal_t *signal) { return RB_NEXT(Tree, &Head, signal); }
static signal_t *Prev(signal_t *signal) { return RB_PREV(Tree, &Head, signal); }
static signal_t *Min(void) { return RB_MIN(Tree, &Head); }
static signal_t *Max(void) { return RB_MAX(Tree, &Head); }
static signal_t *Root(void) { return RB_ROOT(&Head); }
#endif

/*------------------------------------------------------------------------------*
 |                                                                              |
 *------------------------------------------------------------------------------*/

#define _ISOC99_SOURCE_
#include <math.h> /* for HUGE_VAL */
static uint64_t NextCnt = 0;
static double Tnext = HUGE_VAL;

static int TtsSend(lua_State *L)
/* Inserts a new signal in the tree */
    {
    signal_t *signal;
    double at = luaL_checknumber(L, 2);
    if(lua_type(L, 1) != LUA_TTABLE)
        return luaL_argerror(L, 1, "not a table");
    if((signal= (signal_t*)Malloc(L, sizeof(signal_t))) == NULL) 
        return luaL_error(L, errstring(ERR_MEMORY));
    signal->cnt = NextCnt++;
    lua_pushvalue(L, 1);
    signal->ref = luaL_ref(L, LUA_REGISTRYINDEX);
    signal->at = at;
    Insert(signal);
    Tnext = at < Tnext ? at : Tnext;
    return 0;
    }

static int TtsPop(lua_State *L)
/* Returns the next expired signal, or nil if none */
    {
    signal_t *signal;
    if(Tnext > now()) return 0;
    signal = First();
    Remove(signal);
    if(lua_rawgeti(L, LUA_REGISTRYINDEX, signal->ref) != LUA_TTABLE) return unexpected(L);
    luaL_unref(L, LUA_REGISTRYINDEX, signal->ref);
    Free(L, signal);
    /* Update Tnext */
    signal = First();
    Tnext = signal ? signal->at : HUGE_VAL;
    return 1;
    }

static int TtsTnext(lua_State *L)
    {
    lua_pushnumber(L, Tnext);
    return 1;
    }

static int TtsReset(lua_State *L)
/* Deletes all signals */
    {
    signal_t *signal;
    while((signal=First()))
        {
        Remove(signal);
        luaL_unref(L, LUA_REGISTRYINDEX, signal->ref);
        Free(L, signal);
        }
    Tnext = HUGE_VAL;
    NextCnt = 0;
    return 0;
    }


static const struct luaL_Reg Functions[] = 
    {
        { "tts_send", TtsSend },
        { "tts_pop", TtsPop },
        { "tts_tnext", TtsTnext },
        { "tts_reset", TtsReset },
        { NULL, NULL } /* sentinel */
    };


void moonagents_open_tts(lua_State *L)
    {
    luaL_setfuncs(L, Functions, 0);
    }

