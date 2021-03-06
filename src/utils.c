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

/*------------------------------------------------------------------------------*
 | Misc utilities                                                               |
 *------------------------------------------------------------------------------*/

int noprintf(const char *fmt, ...) 
    { (void)fmt; return 0; }

/*------------------------------------------------------------------------------*
 | Malloc                                                                       |
 *------------------------------------------------------------------------------*/

/* We do not use malloc(), free() etc directly. Instead, we inherit the memory 
 * allocator from the main Lua state instead (see lua_getallocf in the Lua manual)
 * and use that.
 *
 * By doing so, we can use an alternative malloc() implementation without recompiling
 * this library (we have needs to recompile lua only, or execute it with LD_PRELOAD
 * set to the path to the malloc library we want to use).
 */
static lua_Alloc Alloc = NULL;
static void* AllocUd = NULL;

static void malloc_init(lua_State *L)
    {
    if(Alloc) unexpected(L);
    Alloc = lua_getallocf(L, &AllocUd);
    }

static void* Malloc_(size_t size)
    { return Alloc ? Alloc(AllocUd, NULL, 0, size) : NULL; }

static void Free_(void *ptr)
    { if(Alloc) Alloc(AllocUd, ptr, 0, 0); }

void *Malloc(lua_State *L, size_t size)
    {
    void *ptr;
    if(size == 0)
        { luaL_error(L, errstring(ERR_MALLOC_ZERO)); return NULL; }
    ptr = Malloc_(size);
    if(ptr==NULL)
        { luaL_error(L, errstring(ERR_MEMORY)); return NULL; }
    memset(ptr, 0, size);
    //DBG("Malloc %p\n", ptr);
    return ptr;
    }

void *MallocNoErr(lua_State *L, size_t size) /* do not raise errors (check the retval) */
    {
    void *ptr = Malloc_(size);
    (void)L;
    if(ptr==NULL)
        return NULL;
    memset(ptr, 0, size);
    //DBG("MallocNoErr %p\n", ptr);
    return ptr;
    }

char *Strdup(lua_State *L, const char *s)
    {
    size_t len = strnlen(s, 256);
    char *ptr = (char*)Malloc(L, len + 1);
    if(len>0)
        memcpy(ptr, s, len);
    ptr[len]='\0';
    return ptr;
    }

void Free(lua_State *L, void *ptr)
    {
    (void)L;
    //DBG("Free %p\n", ptr);
    if(ptr) Free_(ptr);
    }


/*------------------------------------------------------------------------------*
 | Time utilities                                                               |
 *------------------------------------------------------------------------------*/

#if defined(LINUX)


#if 0
static double tstosec(const struct timespec *ts)
    {
    return ts->tv_sec*1.0+ts->tv_nsec*1.0e-9;
    }
#endif

static void sectots(struct timespec *ts, double seconds)
    {
    ts->tv_sec=(time_t)seconds;
    ts->tv_nsec=(long)((seconds-((double)ts->tv_sec))*1.0e9);
    }

double now(void)
    {
#if _POSIX_C_SOURCE >= 199309L
    struct timespec ts;
    if(clock_gettime(CLOCK_MONOTONIC,&ts)!=0)
        { printf("clock_gettime error\n"); return -1; }
    return ts.tv_sec + ts.tv_nsec*1.0e-9;
#else
    struct timeval tv;
    if(gettimeofday(&tv, NULL) != 0)
        { printf("gettimeofday error\n"); return -1; }
    return tv.tv_sec + tv.tv_usec*1.0e-6;
#endif
    }


#if _POSIX_C_SOURCE >= 199309L
void sleeep(double seconds)
    {
    struct timespec ts, ts1;
    struct timespec *req, *rem, *tmp;
    sectots(&ts, seconds);
    req = &ts;
    rem = &ts1;
    while(1)
        {
        if(nanosleep(req, rem) == 0)
            return;
        tmp = req;
        req = rem;
        rem = tmp;
        }
    }
#else
#include <unistd>
void sleeep(double seconds)
    {
    usleep((useconds_t)(seconds*1.0e6));
    }
#endif

#define time_init(L) do { (void)L; /* do nothing */ } while(0)

#elif defined(MINGW)

#include <windows.h>

static LARGE_INTEGER Frequency;
double now(void)
    {
    LARGE_INTEGER ts;
    QueryPerformanceCounter(&ts);
    return ((double)(ts.QuadPart))/Frequency.QuadPart;
    }

void sleeep(double seconds)
    {
    DWORD msec = (DWORD)seconds * 1000;
    //if(msec < 0) return;  DWORD seems to be unsigned
    Sleep(msec);
    }

static void time_init(lua_State *L)
    {
    (void)L;
    QueryPerformanceFrequency(&Frequency);
    }

#endif

/*------------------------------------------------------------------------------*
 | Custom luaL_checkxxx() style functions                                       |
 *------------------------------------------------------------------------------*/

static int checkboolean(lua_State *L, int arg)
    {
    if(!lua_isboolean(L, arg))
        return (int)luaL_argerror(L, arg, "boolean expected");
    return lua_toboolean(L, arg);
    }

#if 0
static int testboolean(lua_State *L, int arg, int *err)
    {
    if(!lua_isboolean(L, arg))
        { *err = ERR_TYPE; return 0; }
    *err = 0;
    return lua_toboolean(L, arg);
    }


static int optboolean(lua_State *L, int arg, int d)
    {
    if(!lua_isboolean(L, arg))
        return d;
    return lua_toboolean(L, arg);
    }
#endif

/*------------------------------------------------------------------------------*
 | Internal error codes                                                         |
 *------------------------------------------------------------------------------*/

const char* errstring(int err)
    {
    switch(err)
        {
        case 0: return "success";
        case ERR_GENERIC: return "generic error";
        case ERR_TABLE: return "not a table";
        case ERR_EMPTY: return "empty list";
        case ERR_TYPE: return "invalid type";
        case ERR_VALUE: return "invalid value";
        case ERR_NOTPRESENT: return "missing";
        case ERR_MEMORY: return "out of memory";
        case ERR_MALLOC_ZERO: return "zero bytes malloc";
        case ERR_LENGTH: return "invalid length";
        case ERR_POOL: return "elements are not from the same pool";
        case ERR_BOUNDARIES: return "invalid boundaries";
        case ERR_UNKNOWN: return "unknown field name";
        default:
            return "???";
        }
    return NULL; /* unreachable */
    }

 
/*------------------------------------------------------------------------------*
 | Lua functions                                                                |
 *------------------------------------------------------------------------------*/

static int Now(lua_State *L)
    {
    lua_pushnumber(L, now());
    return 1;
    }

static int Since(lua_State *L)
    {
    double t = luaL_checknumber(L, 1);
    lua_pushnumber(L, since(t));
    return 1;
    }


/*------------------------------------------------------------------------------*/
/* Rfr: https://en.wikipedia.org/wiki/ANSI_escape_code#Colors
 *      https://rosettacode.org/wiki/Terminal_control/Coloured_text#C
 */
static int TextStyleEnabled = 0;
static int Text_style_enable(lua_State *L)
    {
    TextStyleEnabled = checkboolean(L, 1);
    return 0;
    }

static int Set_text_style(lua_State *L)
    {
    if(!TextStyleEnabled) return 0;
    fflush(stdout);
    if(lua_isnoneornil(L, 1)) /* reset to defaults */
        printf("\033[m");
    else
        {
        int mode, fg, bg;
        int what = 0;
        int t;
        if(!lua_istable(L, 1))
            return luaL_argerror(L, 1, "not a table");
        t = lua_rawgeti(L, 1, 1);
        if(t != LUA_TNIL)
            { fg = checkfgcolor(L, -1); what += 1; }
        t = lua_rawgeti(L, 1, 2);
        if(t != LUA_TNIL)
            { mode = checktextmode(L, -1); what += 2; }
        t = lua_rawgeti(L, 1, 3);
        if(t != LUA_TNIL)
            { bg = checkbgcolor(L, -1); what += 4; }
        lua_pop(L, 3);
        switch(what)
            {
            case 0: break; // empty table: keep current values
            case 1: printf("\033[%dm", fg); break;
            case 2: printf("\033[%dm", mode); break;
            case 3: printf("\033[%d;%dm", mode, fg); break;
            case 4: printf("\033[%dm", bg); break;
            case 5: printf("\033[%d;%dm", bg, fg); break;
            case 6: printf("\033[%d;%dm", mode, bg); break;
            case 7: printf("\033[%d;%d;%dm", mode, bg, fg); break;
            }
        }
    fflush(stdout);
    return 0;
    }

static const struct luaL_Reg Functions[] = 
    {
        { "now", Now },
        { "since", Since },
        { "text_style_enable", Text_style_enable },
        { "set_text_style", Set_text_style },
        { NULL, NULL } /* sentinel */
    };

/*------------------------------------------------------------------------------*
 | Inits                                                                        |
 *------------------------------------------------------------------------------*/

void moonagents_utils_init(lua_State *L)
    {
    malloc_init(L);
    time_init(L);
    }

void moonagents_open_utils(lua_State *L)
    {
    luaL_setfuncs(L, Functions, 0);
    }

