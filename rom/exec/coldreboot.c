/*
    (C) 1995-1997 AROS - The Amiga Replacement OS
    $Id$

    Desc: ColdReboot() - Reboot the computer.
    Lang: english
*/

extern void aros_print_not_implemented(char *);

/*****************************************************************************

    NAME */
#include <proto/exec.h>

	AROS_LH0(void, ColdReboot,

/*  LOCATION */
	struct ExecBase *, SysBase, 121, Exec)

/*  FUNCTION
	This function will reboot the computer.

    INPUTS
	None.

    RESULT
	This function does not return.

    NOTES
	It can be quite harmful to call this function. It may be possible that
	you will lose data from other tasks not having saved, or disk buffers
	not being flushed. Plus you could annoy the (other) users.

    EXAMPLE

    BUGS

    SEE ALSO

    INTERNALS
	This function is not really necessary, and could be left unimplemented
	on many systems. It is best when using this function to allow the memory
	contents to remain as they are, since some programs may use this
	function when installing resident modules.

    HISTORY

******************************************************************************/
{
    AROS_LIBFUNC_INIT

    aros_print_not_implemented("ColdReboot");

    AROS_LIBFUNC_EXIT
} /* ColdReboot() */
