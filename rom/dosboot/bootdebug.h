/*
    Copyright (C) 2026, The AROS Development Team. All rights reserved.

    Include after other headers in boot-only translation units. Keep explicit
    DEBUG builds unchanged, but make existing boot diagnostics available through
    sysdebug=Init even in normal builds. D accepts statement lists, with or
    without a trailing semicolon at the call site, like aros/debug.h.
*/

#ifndef DOSBOOT_BOOTDEBUG_H
#define DOSBOOT_BOOTDEBUG_H

#include <exec/execbase.h>

#if !DEBUG && !defined(NO_RUNTIME_DEBUG)
#undef D
#define D(...) do { \
    if (SysBase->ex_DebugFlags & EXECDEBUGF_INIT) { __VA_ARGS__; } \
} while (0);
#endif

#endif
