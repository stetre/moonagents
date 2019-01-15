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

/********************************************************************************
 * Internal common header                                                       *
 ********************************************************************************/

#ifndef internalDEFINED
#define internalDEFINED

#ifdef LINUX
#define _ISOC11_SOURCE /* see man aligned_alloc(3) */
#endif
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include "moonagents.h"
#include "tree.h"
#include "enums.h"

#define TOSTR_(x) #x
#define TOSTR(x) TOSTR_(x)

/* Note: all the dynamic symbols of this library (should) start with 'moonagents_' .
 * The only exception is the luaopen_moonagents() function, which is searched for
 * with that name by Lua.
 * MoonAgents's string references on the Lua registry also start with 'moonagents_'.
 */


#if 0
/* .c */
#define  moonagents_
#endif

/* utils.c */
#define noprintf moonagents_noprintf
int noprintf(const char *fmt, ...); 
#define now moonagents_now
double now(void);
#define sleeep moonagents_sleeep
void sleeep(double seconds);
#define since(t) (now() - (t))
#define Malloc moonagents_Malloc
void *Malloc(lua_State *L, size_t size);
#define MallocNoErr moonagents_MallocNoErr
void *MallocNoErr(lua_State *L, size_t size);
#define Strdup moonagents_Strdup
char *Strdup(lua_State *L, const char *s);
#define Free moonagents_Free
void Free(lua_State *L, void *ptr);

/* main.c */
int luaopen_moonagents(lua_State *L);
void moonagents_utils_init(lua_State *L);
void moonagents_open_utils(lua_State *L);
void moonagents_open_enums(lua_State *L);
void moonagents_open_timers(lua_State *L);
void moonagents_open_tts(lua_State *L);

/*------------------------------------------------------------------------------*
 | Debug and other utilities                                                    |
 *------------------------------------------------------------------------------*/
/* If this is printed, it denotes a suspect bug: */
#define UNEXPECTED_ERROR "unexpected error (%s, %d)", __FILE__, __LINE__
#define unexpected(L) luaL_error((L), UNEXPECTED_ERROR)

#define notsupported(L) luaL_error((L), "operation not supported")

#define badvalue(L,s)   lua_pushfstring((L), "invalid value '%s'", (s))

/* Internal error codes */
#define ERR_NOTPRESENT       1
#define ERR_SUCCESS          0
#define ERR_GENERIC         -1
#define ERR_TYPE            -2
#define ERR_VALUE           -3
#define ERR_TABLE           -4
#define ERR_EMPTY           -5
#define ERR_MEMORY          -6
#define ERR_MALLOC_ZERO     -7
#define ERR_LENGTH          -8
#define ERR_POOL            -9
#define ERR_BOUNDARIES      -10
#define ERR_UNKNOWN         -11

#define errstring moonagents_errstring
const char* errstring(int err);


/* DEBUG -------------------------------------------------------- */
#if defined(DEBUG)

#define DBG printf
#define TR() do { printf("trace %s %d\n",__FILE__,__LINE__); } while(0)
#define BK() do { printf("break %s %d\n",__FILE__,__LINE__); getchar(); } while(0)
#define TSTART double ts = now();
#define TSTOP do {                                          \
    ts = since(ts); ts = ts*1e6;                            \
    printf("%s %d %.3f us\n", __FILE__, __LINE__, ts);      \
    ts = now();                                             \
} while(0);

#else 

#define DBG noprintf
#define TR()
#define BK()
#define TSTART do {} while(0) 
#define TSTOP do {} while(0)    

#endif /* DEBUG ------------------------------------------------- */


#endif /* internalDEFINED */
