/*
    Copyright � 2024, The AROS Development Team. All rights reserved.
    $Id$
*/

#ifndef RESOURCES_DOSBOOT_H
#define RESOURCES_DOSBOOT_H

#include <libraries/expansionbase.h>
#include <proto/exec.h>
#include <proto/dosboot.h>

#include <stdarg.h>

static inline void dosboot_Log2(CONST_STRPTR fmt, ...) {
	struct Library *DOSBootBase = OpenResource("dosboot.resource");

	if (!(DOSBootBase = OpenResource("dosboot.resource"))) return;
	dosboot_Log(fmt, (RAWARG)(&fmt+1));
};

#endif /* RESOURCES_DOSBOOT_H */
