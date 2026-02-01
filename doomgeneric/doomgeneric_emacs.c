/* DOOM on Emacs

Copyright (C) 2012-2026 doomgeneric contributors, Akhsarbek Gozoev, bcoles,
  Daniel Bomar, Daniel Mendler, Fabian Ruhland, Georgi Gerganov,
  indigoparadox, isif00, lukneu, Maxime Vincent, Ørjan, ozkl, techflashYT,
  Travis Bradshaw, Trider12, Turo Lamminen
Copyright (C) 1993-1996 Id Software, Inc.

GNU Emacs is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or (at
your option) any later version.

GNU Emacs is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.  */

#include "doomkeys.h"
#include "doomgeneric.h"
#include <emacs-module.h>
#include <string.h>

static emacs_value Qnil, Qaccept_process_output, Qdoom_key, Qdoom_ms,
    Qdoom_canvas, Qdoom_title;
static emacs_env* env;
int plugin_is_GPL_compatible;

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
    uint32_t* buf = env->is_not_nil (env, canvas) ? env->canvas_pixel(env, canvas) : 0;
    if (buf) {
        memcpy(buf, DG_ScreenBuffer, 4 * DOOMGENERIC_RESX * DOOMGENERIC_RESY);
        env->canvas_refresh(env, canvas);
    }
}

int DG_GetKey(int* pressed, unsigned char* key) {
    int i = (int)env->extract_integer(env, env->funcall(env, Qdoom_key, 0, 0));
    *key = i & 255;
    *pressed = i >> 8;
    return i != 0;
}

static emacs_value sym(const char* name) {
    return env->make_global_ref(env, env->intern(env, name));
}

static emacs_value tick(emacs_env* env_, ptrdiff_t nargs,
                        emacs_value args[], void* data) {
    env = env_;
    doomgeneric_Tick();
    return Qnil;
}

int emacs_module_init(struct emacs_runtime *rt) {
    if ((size_t)rt->size < sizeof (*rt))
        return 1;
    env = rt->get_environment(rt);
    if ((size_t)env->size < sizeof (*env))
        return 2;
    Qnil = sym("nil");
    Qaccept_process_output = sym("accept-process-output");
    Qdoom_ms = sym("doom-ms");
    Qdoom_canvas = sym("doom-canvas");
    Qdoom_key = sym("doom-key");
    Qdoom_title = sym("doom-title");
    env->funcall(env, env->intern(env, "defalias"), 2,
                 (emacs_value[]){
                     env->intern(env, "doom-tick"),
                     env->make_function(env, 0, 0, tick, 0, 0)
                 });
    doomgeneric_Create(0, 0);
    return 0;
}
