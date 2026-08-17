/* DOOM on Emacs

Copyright (C) 2012-2026 doomgeneric contributors, Akhsarbek Gozoev, bcoles,
  Daniel Bomar, Daniel Mendler, Fabian Ruhland, Georgi Gerganov,
  indigoparadox, isif00, lukneu, Maxime Vincent, Ørjan, ozkl, techflashYT,
  Travis Bradshaw, Trider12, Turo Lamminen
Copyright (C) 1993-1996 Id Software, Inc.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>. */

#include "doomkeys.h"
#include "doomgeneric.h"
#include "emacs-module.h"
#include <setjmp.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>

static emacs_value Qnil, Qaccept_process_output, Qcanvas_refresh,
    Qdoom_key, Qdoom_ms, Qdoom_canvas, Qdoom_title, Qdoom_log;
static emacs_env* env;
static jmp_buf jmp;
static bool exited = false;
int plugin_is_GPL_compatible;

static int doom_log(const char* fmt, va_list va) {
    char buf[1024];
    int len = vsnprintf(buf, sizeof (buf), fmt, va);
    env->funcall(env, Qdoom_log, 1,
                 (emacs_value[]){ env->make_string(env, buf, len) });
    return len;
}

int DG_vfprintf(FILE* fp, const char* fmt, va_list va) {
    return fp == stderr || fp == stdout
        ? doom_log(fmt, va)
        : (vfprintf)(stderr, fmt, va);
}

int DG_fprintf(FILE* fp, const char* fmt, ...) {
    va_list va;
    va_start(va, fmt);
    int len = DG_vfprintf(fp, fmt, va);
    va_end(va);
    return len;
}

int DG_printf(const char* fmt, ...) {
    va_list va;
    va_start(va, fmt);
    int len = doom_log(fmt, va);
    va_end(va);
    return len;
}

int DG_putchar(int c) {
    return DG_printf("%c", c);
}

int DG_putc(int c, FILE* fp) {
    return DG_fprintf(fp, "%c", c);
}

int DG_puts(const char* s) {
    return DG_printf("%s\n", s);
}

void DG_exit(int status) {
    exited = true;
    DG_puts("DOOM exited. Restart Emacs to play again.");
    longjmp(jmp, 1);
}

void DG_Init(void) {
}

void DG_SetWindowTitle(const char* x) {
    env->funcall(env, Qdoom_title, 1,
                 (emacs_value[]){ env->make_string(env, x, strlen(x)) });
}

void DG_SleepMs(uint32_t x) {
    env->funcall(env, Qaccept_process_output, 2,
                 (emacs_value[]){ Qnil, env->make_float(env, x * 0.001) });
}

uint32_t DG_GetTicksMs(void) {
    return (uint32_t)env->extract_integer(env, env->funcall(env, Qdoom_ms, 0, 0));
}

void DG_DrawFrame(void) {
    emacs_value canvas = env->funcall(env, Qdoom_canvas, 0, 0);
    uint32_t* buf = env->is_not_nil (env, canvas) ? env->canvas_data(env, canvas) : 0;
    if (buf) {
        memcpy(buf, DG_ScreenBuffer, 4 * DOOMGENERIC_RESX * DOOMGENERIC_RESY);
        env->funcall(env, Qcanvas_refresh, 1, &canvas);
    }
}

int DG_GetKey(int* pressed, unsigned char* key) {
    int i = (int)env->extract_integer(env, env->funcall(env, Qdoom_key, 0, 0));
    *key = i & 255;
    *pressed = i >> 8;
    return i != 0;
}

static emacs_value doom_tick(emacs_env* env_, ptrdiff_t nargs,
                             emacs_value args[], void* data) {
    env = env_;
    if (!exited && !setjmp(jmp))
        doomgeneric_Tick();
    return Qnil;
}

static emacs_value doom_create(emacs_env* env_, ptrdiff_t nargs,
                               emacs_value args[], void* data) {
    env = env_;
    char** argv = malloc(sizeof (char*) * (nargs + 2));
    if (!argv) {
        exited = true;
        return Qnil;
    }
    argv[0] = "doom";
    argv[nargs + 1] = 0;
    for (ptrdiff_t i = 1; i <= nargs; ++i) {
        ptrdiff_t size = 0;
        if (!env->copy_string_contents(env, args[i - 1], 0, &size)
            || !(argv[i] = malloc(size))
            || !env->copy_string_contents(env, args[i - 1], argv[i], &size))
            return Qnil;
    }
    if (!setjmp(jmp))
        doomgeneric_Create(nargs + 1, argv);
    return Qnil;
}

static emacs_value sym(const char* name) {
    return env->make_global_ref(env, env->intern(env, name));
}

static void defun(emacs_env* env, const char* name,
                  ptrdiff_t min, ptrdiff_t max, void* fun) {
    env->funcall(env, env->intern(env, "defalias"), 2,
                 (emacs_value[]){
                     env->intern(env, name),
                     env->make_function(env, min, max, fun, 0, 0)
                 });
}

int emacs_module_init(struct emacs_runtime *rt) {
    if ((size_t)rt->size < sizeof (*rt))
        return 1;
    env = rt->get_environment(rt);
    if ((size_t)env->size < sizeof (*env))
        return 2;
    Qnil = sym("nil");
    Qaccept_process_output = sym("accept-process-output");
    Qcanvas_refresh = sym("canvas-refresh");
    Qdoom_ms = sym("doom--ms");
    Qdoom_canvas = sym("doom--canvas");
    Qdoom_key = sym("doom--key");
    Qdoom_title = sym("doom--title");
    Qdoom_log = sym("doom--log");
    defun(env, "doom--tick", 0, 0, doom_tick);
    defun(env, "doom--create", 0, emacs_variadic_function, doom_create);
    return 0;
}
