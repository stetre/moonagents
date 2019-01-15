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
 
/* "A timer is active from the moment of setting up to the moment of
 *  consumption of the timer signal" (Z101/11.15).
 *  So, when the timer has expired and the signal is scheduled but not
 *  yet consumed, the timer is to be regarded as active (even if it is
 *  not active in the timers module). If the agent stops the signal
 *  while the signal is already scheduled, the signal must be discarded.
 */
#define STATUS_INACTIVE     0 /* inactive, not armed */
#define STATUS_ARMED        1 /* active, armed (signal not scheduled) */
#define STATUS_NOT_ARMED    2 /* active, not armed (signal scheduled) */

#define timer_t struct timer_s
struct timer_s {
    RB_ENTRY(timer_s) Entry;
    RB_ENTRY(timer_s) ArmedEntry;
    uint32_t tid;     /* search key */
    double duration;  /* default duration (seconds) */
    double exptime;   /* expiration time based on now() */
    uint32_t owner;   /* owner agent's pid */
    int signame_ref;  /* signal name (reference on Lua registry */
    uint16_t status;  /* timer status */
    uint16_t discard_count; /* signals to be discarded */
};

static int cmp(timer_t *timer1, timer_t *timer2) 
    { return timer1->tid < timer2->tid ? -1 : timer1->tid > timer2->tid; }

static RB_HEAD(Tree, timer_s) Head = RB_INITIALIZER(&Head);
RB_PROTOTYPE_STATIC(Tree, timer_s, Entry, cmp) 
RB_GENERATE_STATIC(Tree, timer_s, Entry, cmp) 

static timer_t *Remove(timer_t *timer) { return RB_REMOVE(Tree, &Head, timer); }
static timer_t *Insert(timer_t *timer) { return RB_INSERT(Tree, &Head, timer); }
static timer_t *Search(uint32_t tid) { timer_t tmp; tmp.tid = tid; return RB_FIND(Tree, &Head, &tmp); }
static timer_t *First(uint32_t tid) { timer_t tmp; tmp.tid = tid; return RB_NFIND(Tree, &Head, &tmp); }
#if 0
static timer_t *Next(timer_t *timer) { return RB_NEXT(Tree, &Head, timer); }
static timer_t *Prev(timer_t *timer) { return RB_PREV(Tree, &Head, timer); }
static timer_t *Min(void) { return RB_MIN(Tree, &Head); }
static timer_t *Max(void) { return RB_MAX(Tree, &Head); }
static timer_t *Root(void) { return RB_ROOT(&Head); }
#endif

static int active_cmp(timer_t *timer1, timer_t *timer2) 
    {
    if(timer1->exptime < timer2->exptime) return -1;
    if(timer1->exptime > timer2->exptime) return 1;
    return timer1->tid < timer2->tid ? -1 : timer1->tid > timer2->tid;
    }

static RB_HEAD(ArmedTree, timer_s) ArmedHead = RB_INITIALIZER(&ArmedHead);
RB_PROTOTYPE_STATIC(ArmedTree, timer_s, ArmedEntry, active_cmp) 
RB_GENERATE_STATIC(ArmedTree, timer_s, ArmedEntry, active_cmp) 

static timer_t *ArmedRemove(timer_t *timer) { return RB_REMOVE(ArmedTree, &ArmedHead, timer); }
static timer_t *ArmedInsert(timer_t *timer) { return RB_INSERT(ArmedTree, &ArmedHead, timer); }
#if 0
static timer_t *ArmedSearch(uint32_t tid, double exptime)
    { timer_t tmp; tmp.exptime = exptime; tmp.tid = tid; return RB_FIND(ArmedTree, &ArmedHead, &tmp); }
#endif
static timer_t *ArmedFirst(void)
    { timer_t tmp; tmp.exptime = 0.0; tmp.tid = 0; return RB_NFIND(ArmedTree, &ArmedHead, &tmp); }
#if 0
static timer_t *ArmedNext(timer_t *timer) { return RB_NEXT(ArmedTree, &ArmedHead, timer); }
static timer_t *ArmedPrev(timer_t *timer) { return RB_PREV(ArmedTree, &ArmedHead, timer); }
static timer_t *ArmedMin(void) { return RB_MIN(ArmedTree, &ArmedHead); }
static timer_t *ArmedMax(void) { return RB_MAX(ArmedTree, &ArmedHead); }
static timer_t *ArmedRoot(void) { return RB_ROOT(&ArmedHead); }
#endif

/*------------------------------------------------------------------------------*
 |                                                                              |
 *------------------------------------------------------------------------------*/

#define _ISOC99_SOURCE_
#include <math.h> /* for HUGE_VAL */
static uint32_t NextTid;
static double Tnext;
static int CallbackRef = LUA_NOREF;

static int Deactivate(timer_t *timer)
/* if armed, delete from the list of armed timers */
    {
    if(timer->status != STATUS_ARMED) return 0;
    //printf("Deactivate timer %d %g\n", timer->tid, timer->exptime);
    ArmedRemove(timer);
    return 0;
    }

static int Delete(lua_State *L, timer_t *timer)
    {
    //printf("Delete timer %d %g\n", timer->tid, timer->exptime);
    Deactivate(timer);
    Remove(timer);
    luaL_unref(L, LUA_REGISTRYINDEX, timer->signame_ref);
    Free(L, timer);   
    return 0;
    }

static int Timers_reset(lua_State *L)
    {
    timer_t *timer;
    while((timer=First(0)))
        Delete(L, timer);
    if(CallbackRef != LUA_NOREF)
        {
        luaL_unref(L, LUA_REGISTRYINDEX, CallbackRef);
        CallbackRef = LUA_NOREF;
        }
    return 0;
    }

static int Timers_init(lua_State *L)
    {
    if(CallbackRef != LUA_NOREF) Timers_reset(L);
    if(!lua_isfunction(L, 1))
        return luaL_argerror(L, 1, "missing or invalid callback");
    lua_pushvalue(L, 1);
    CallbackRef = luaL_ref(L, LUA_REGISTRYINDEX);
    Tnext = HUGE_VAL;
    NextTid = 1;
    return 0;
    }

static int Timers_trigger(lua_State *L)
/* Execute callbacks for all timers with exptime <= now */
    {
    int top;
    timer_t *timer;
    double tnow = now();
    if(tnow < Tnext) return 0;
    while((timer = ArmedFirst())!=NULL)
        {
        top = lua_gettop(L);
        if(timer->exptime > tnow) break;
        // timer expired, execute callback
        //printf("Expired timer %d %g\n", timer->tid, timer->exptime);
        Deactivate(timer);
        timer->status = STATUS_NOT_ARMED;
        if(lua_rawgeti(L, LUA_REGISTRYINDEX, CallbackRef) != LUA_TFUNCTION)
            return unexpected(L);
        lua_pushinteger(L, timer->tid);
        lua_pushinteger(L, timer->owner);
        if(lua_rawgeti(L, LUA_REGISTRYINDEX, timer->signame_ref) != LUA_TSTRING)
            return unexpected(L);
        if(lua_pcall(L, 3, 0, 0) != LUA_OK)
            return lua_error(L);
        lua_settop(L, top);
        }
    timer = ArmedFirst();
    Tnext = timer ? timer->exptime : HUGE_VAL;
    return 0;
    }

static int Timers_create(lua_State *L)
    {
    int ref;
    timer_t *timer;
    uint32_t owner= luaL_checkinteger(L, 1);
    double duration = luaL_checknumber(L, 2);
    (void)luaL_checkstring(L, 3);
    if(Search(NextTid)) return unexpected(L);
    lua_pushvalue(L, 3);
    ref = luaL_ref(L, LUA_REGISTRYINDEX);
    if((timer= (timer_t*)Malloc(L, sizeof(timer_t))) == NULL) 
        return luaL_error(L, errstring(ERR_MEMORY));
    memset(timer, 0, sizeof(timer_t));
    timer->owner= owner;
    timer->duration = duration;
    timer->exptime = 0.0f;
    timer->tid = NextTid++;
    timer->signame_ref = ref;
    timer->status = STATUS_INACTIVE;
    timer->discard_count = 0;
    Insert(timer);
    lua_pushinteger(L, timer->tid);
    return 1;
    }

static int Timers_delete(lua_State *L)
    {
    uint32_t tid = luaL_checkinteger(L, 1);
    timer_t *timer = Search(tid);
    if(!timer) return luaL_argerror(L, 1, "unknown tid");
    Delete(L, timer);
    return 0;
    }


static int Timers_start(lua_State *L)
    {
    double exptime;
    uint32_t tid = luaL_checkinteger(L, 1);
    timer_t *timer = Search(tid);
    if(!timer) return luaL_argerror(L, 1, "unknown tid");
    exptime = luaL_optnumber(L, 2, now() + timer->duration);
    Deactivate(timer);
    timer->exptime = exptime;
    //printf("Activate timer %d %g\n", timer->tid, timer->exptime);
    ArmedInsert(timer);
    timer->status = STATUS_ARMED;
    Tnext = exptime < Tnext ? exptime : Tnext;
    lua_pushnumber(L, exptime);
    return 1;
    }

static int Stop(lua_State *L, timer_t *timer)
    {
    switch(timer->status)
        {
        case STATUS_INACTIVE: break;
        case STATUS_ARMED: Deactivate(timer); /* signal not yet scheduled */
                break;
        case STATUS_NOT_ARMED:
                /* The timer is already expired, but the associated signal has
                 * not yet reached the owner agent so it must be discarded by
                 * the signal scheduler (because from the agent's point of view
                 * the timer was already running)
                 */
                timer->discard_count++;
                break;
        default: unexpected(L);
        }
    timer->status = STATUS_INACTIVE;
    return 0;
    }


static int Timers_stop(lua_State *L)
    {
    double t = now();
    uint32_t tid = luaL_checkinteger(L, 1);
    timer_t *timer = Search(tid);
    if(!timer) return luaL_argerror(L, 1, "unknown tid");
    Stop(L, timer);
    lua_pushnumber(L, t);
    return 1;
    }

static int Timers_timeout(lua_State *L)
    {
    uint32_t tid = luaL_checkinteger(L, 1);
    timer_t *timer = Search(tid);
    if(!timer) return luaL_argerror(L, 1, "unknown tid");
    lua_pushnumber(L, timer->duration);
    return 1;
    }

static int Timers_isrunning(lua_State *L)
    { 
    uint32_t tid = luaL_checkinteger(L, 1);
    timer_t *timer = Search(tid);
    if(!timer) return luaL_argerror(L, 1, "unknown tid");
    if(timer->status != STATUS_INACTIVE)
        {
        lua_pushboolean(L, 1);
        lua_pushnumber(L, timer->exptime);
        }
    else
        {
        lua_pushboolean(L, 0);
        lua_pushnumber(L, HUGE_VAL);
        }
    return 2;
    }

static int Timers_discard(lua_State *L)
/* To be called when the signal reaches the agent, returns true if the
 * signal is stale and must be discarded, false if it is valid.
 * Also manages discard_count and status.
 */
    {
    int stale=0;
    uint32_t tid = luaL_checkinteger(L, 1);
    timer_t *timer = Search(tid);
    if(!timer) return luaL_argerror(L, 1, "unknown tid");
    if(timer->discard_count > 0)
        {
        /* The timer that caused this signal was stopped after the signal
         * was sent, so the signal must be discarded */
        stale = 1;
        timer->discard_count--;
        }
    if(timer->discard_count==0 && timer->status!=STATUS_ARMED)
        timer->status = STATUS_INACTIVE;
    lua_pushboolean(L, stale);
    return 1;
    }

static int Timers_signame(lua_State *L)
    { 
    uint32_t tid = luaL_checkinteger(L, 1);
    timer_t *timer = Search(tid);
    if(!timer) return luaL_argerror(L, 1, "unknown tid");
    if(lua_rawgeti(L, LUA_REGISTRYINDEX, timer->signame_ref) != LUA_TSTRING)
        return unexpected(L);
    return 1;
    }

static int Timers_set_signame(lua_State *L)
    { 
    uint32_t tid = luaL_checkinteger(L, 1);
    timer_t *timer = Search(tid);
    if(!timer) return luaL_argerror(L, 1, "unknown tid");
    Stop(L, timer);
    (void)luaL_checkstring(L, 2);
    luaL_unref(L, LUA_REGISTRYINDEX, timer->signame_ref);
    lua_pushvalue(L, 2);
    timer->signame_ref = luaL_ref(L, LUA_REGISTRYINDEX);
    return 0;
    }

static int Timers_duration(lua_State *L)
    { 
    uint32_t tid = luaL_checkinteger(L, 1);
    timer_t *timer = Search(tid);
    if(!timer) return luaL_argerror(L, 1, "unknown tid");
    lua_pushnumber(L, timer->duration);
    return 1;
    }

static int Timers_set_duration(lua_State *L)
    { 
    uint32_t tid = luaL_checkinteger(L, 1);
    timer_t *timer = Search(tid);
    if(!timer) return luaL_argerror(L, 1, "unknown tid");
    Stop(L, timer);
    timer->duration = luaL_checknumber(L, 2);
    return 0;
    }

static int Timers_check_owner(lua_State *L)
    { 
    uint32_t tid = luaL_checkinteger(L, 1);
    uint32_t owner = luaL_checkinteger(L, 2);
    timer_t *timer = Search(tid);
    if(!timer) return luaL_error(L, "unknown timer %u", tid);
    if(owner != timer->owner) 
        return luaL_error(L, "pid %d is not the owner of timer %u", owner, tid);
    return 0;
    }

static int Timers_tnext(lua_State *L)
    {
    lua_pushnumber(L, Tnext);
    return 1;
    }

static const struct luaL_Reg Functions[] = 
    {
        { "timers_init", Timers_init },
        { "timers_reset", Timers_reset },
        { "timers_trigger", Timers_trigger },
        { "timers_create", Timers_create },
        { "timers_delete", Timers_delete },
        { "timers_start", Timers_start },
        { "timers_stop", Timers_stop },
        { "timers_timeout", Timers_timeout },
        { "timers_isrunning", Timers_isrunning },
        { "timers_discard", Timers_discard },
        { "timers_signame", Timers_signame },
        { "timers_set_signame", Timers_set_signame },
        { "timers_duration", Timers_duration },
        { "timers_set_duration", Timers_set_duration },
        { "timers_check_owner", Timers_check_owner },
        { "timers_tnext", Timers_tnext },
        { NULL, NULL } /* sentinel */
    };


void moonagents_open_timers(lua_State *L)
    {
    luaL_setfuncs(L, Functions, 0);
    }

