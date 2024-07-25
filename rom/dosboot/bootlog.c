/*
    Copyright � 2020, The AROS Development Team. All rights reserved.
*/

#include <proto/exec.h>
#include <exec/rawfmt.h>

/*****************************************************************************

    NAME */
#include <proto/dosboot.h>
#include <proto/graphics.h>
#include <proto/intuition.h>

#include "dosboot_intern.h"

#include <stdio.h>
#include <stdarg.h>


AROS_LH2(void, dosboot_Log,

/*  SYNOPSIS */
	AROS_LHA(CONST_STRPTR, format,   D1),
	AROS_LHA(RAWARG,       argarray, D2),

/*  LOCATION */
	struct DOSBootBase *, DOSBootBase, 1, Dosboot)

/*  FUNCTION

*****************************************************************************/
{
	AROS_LIBFUNC_INIT

	if (!DOSBootBase)
	{
		/* ??? What ??? */
		return;
	}

	const int lineHeight = 8;
	int currentY = (DOSBootBase->debug_pos++)*lineHeight;
	char buf[256];
	vsprintf(buf, format, argarray);
	struct Window *win = DOSBootBase->bm_Window;
	if (currentY + lineHeight >= win->Height) {
		// Scroll the content up

		ScrollRaster(win->RPort, 0, lineHeight, 0, 0, win->Width - 1, win->Height - 1);
		currentY -= lineHeight;
		DOSBootBase->debug_pos--;
	}

	//norm_text(DOSBootBase, 2, 1, currentY, buf);
	struct IntuiText it = {
			2, 1,
			JAM2,
			0, 0,
			NULL,
			buf,
			NULL
	};

	PrintIText(win->RPort, &it, 1, currentY);


	AROS_LIBFUNC_EXIT
}

