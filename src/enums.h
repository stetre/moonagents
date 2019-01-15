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

#ifndef enumsDEFINED
#define enumsDEFINED

/* enums.c */
#define enums_free_all moonagents_enums_free_all
void enums_free_all(lua_State *L);
#define enums_test moonagents_enums_test
uint32_t enums_test(lua_State *L, uint32_t domain, int arg, int *err);
#define enums_check moonagents_enums_check
uint32_t enums_check(lua_State *L, uint32_t domain, int arg);
#define enums_push moonagents_enums_push
int enums_push(lua_State *L, uint32_t domain, uint32_t code);
#define enums_values moonagents_enums_values
int enums_values(lua_State *L, uint32_t domain);
#define enums_checklist moonagents_enums_checklist
uint32_t* enums_checklist(lua_State *L, uint32_t domain, int arg, uint32_t *count, int *err);
#define enums_freelist moonagents_enums_freelist
void enums_freelist(lua_State *L, uint32_t *list);


/* Enum domains */
#define DOMAIN_TEXT_MODE    0
#define DOMAIN_BG_COLOR     1
#define DOMAIN_FG_COLOR     2

/* Text mode */
#define MOONAGENTS_TEXT_MODE_NORMAL 22
#define MOONAGENTS_TEXT_MODE_BOLD   1
#define MOONAGENTS_TEXT_MODE_FAINT  2
#define MOONAGENTS_TEXT_MODE_ITALIC 3
#define MOONAGENTS_TEXT_MODE_UNDERLINE  4
#define MOONAGENTS_TEXT_MODE_BLINK  5
#define MOONAGENTS_TEXT_MODE_INVERTED   7

/* Background color */
#define MOONAGENTS_BG_COLOR_BLACK           40
#define MOONAGENTS_BG_COLOR_RED             41
#define MOONAGENTS_BG_COLOR_GREEN           42
#define MOONAGENTS_BG_COLOR_YELLOW          43
#define MOONAGENTS_BG_COLOR_BLUE            44
#define MOONAGENTS_BG_COLOR_MAGENTA         45
#define MOONAGENTS_BG_COLOR_CYAN            46
#define MOONAGENTS_BG_COLOR_WHITE           47
#define MOONAGENTS_BG_COLOR_BRIGHT_BLACK    100
#define MOONAGENTS_BG_COLOR_BRIGHT_RED      101
#define MOONAGENTS_BG_COLOR_BRIGHT_GREEN    102
#define MOONAGENTS_BG_COLOR_BRIGHT_YELLOW   103
#define MOONAGENTS_BG_COLOR_BRIGHT_BLUE     104
#define MOONAGENTS_BG_COLOR_BRIGHT_MAGENTA  105
#define MOONAGENTS_BG_COLOR_BRIGHT_CYAN     106
#define MOONAGENTS_BG_COLOR_BRIGHT_WHITE    107

/* Foreground color */
#define MOONAGENTS_FG_COLOR_BLACK           30
#define MOONAGENTS_FG_COLOR_RED             31
#define MOONAGENTS_FG_COLOR_GREEN           32
#define MOONAGENTS_FG_COLOR_YELLOW          33
#define MOONAGENTS_FG_COLOR_BLUE            34
#define MOONAGENTS_FG_COLOR_MAGENTA         35
#define MOONAGENTS_FG_COLOR_CYAN            36
#define MOONAGENTS_FG_COLOR_WHITE           37
#define MOONAGENTS_FG_COLOR_BRIGHT_BLACK    90
#define MOONAGENTS_FG_COLOR_BRIGHT_RED      91
#define MOONAGENTS_FG_COLOR_BRIGHT_GREEN    92
#define MOONAGENTS_FG_COLOR_BRIGHT_YELLOW   93
#define MOONAGENTS_FG_COLOR_BRIGHT_BLUE     94
#define MOONAGENTS_FG_COLOR_BRIGHT_MAGENTA  95
#define MOONAGENTS_FG_COLOR_BRIGHT_CYAN     96
#define MOONAGENTS_FG_COLOR_BRIGHT_WHITE    97

#define testtextmode(L, arg, err) (uint32_t)enums_test((L), DOMAIN_TEXT_MODE, (arg), (err))
#define checktextmode(L, arg) (uint32_t)enums_check((L), DOMAIN_TEXT_MODE, (arg))
#define pushtextmode(L, val) enums_push((L), DOMAIN_TEXT_MODE, (uint32_t)(val))
#define valuestextmode(L) enums_values((L), DOMAIN_TEXT_MODE)

#define testbgcolor(L, arg, err) (uint32_t)enums_test((L), DOMAIN_BG_COLOR, (arg), (err))
#define checkbgcolor(L, arg) (uint32_t)enums_check((L), DOMAIN_BG_COLOR, (arg))
#define pushbgcolor(L, val) enums_push((L), DOMAIN_BG_COLOR, (uint32_t)(val))
#define valuesbgcolor(L) enums_values((L), DOMAIN_BG_COLOR)

#define testfgcolor(L, arg, err) (uint32_t)enums_test((L), DOMAIN_FG_COLOR, (arg), (err))
#define checkfgcolor(L, arg) (uint32_t)enums_check((L), DOMAIN_FG_COLOR, (arg))
#define pushfgcolor(L, val) enums_push((L), DOMAIN_FG_COLOR, (uint32_t)(val))
#define valuesfgcolor(L) enums_values((L), DOMAIN_FG_COLOR)


#if 0 /* scaffolding 6yy */
#define testxxx(L, arg, err) (uint32_t)enums_test((L), DOMAIN_XXX, (arg), (err))
#define checkxxx(L, arg) (uint32_t)enums_check((L), DOMAIN_XXX, (arg))
#define pushxxx(L, val) enums_push((L), DOMAIN_XXX, (uint32_t)(val))
#define valuesxxx(L) enums_values((L), DOMAIN_XXX)
    CASE(xxx);

#endif

#endif /* enumsDEFINED */


