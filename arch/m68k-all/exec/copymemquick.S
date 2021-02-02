/*
    Copyright © 1995-2012, The AROS Development Team. All rights reserved.
    $Id$

    Desc: Optimized CopyMemQuick by Gunnar von Boehn.
    Lang: english
*/

	#include "aros/m68k/asm.h"

#define UNALIGNEDWARNING 1

	.text
	.balign 4

	.globl	AROS_SLIB_ENTRY(CopyMemQuick,Exec,105)
	.type	AROS_SLIB_ENTRY(CopyMemQuick,Exec,105),@function
AROS_SLIB_ENTRY(CopyMemQuick,Exec,105):

#ifdef NONVAMPIRE
#if UNALIGNEDWARNING
	move.w	%d0,%d1
	and.w	#3,%d1
	beq.s	0f
	movem.l %d0-%d1/%a0-%a1,-(%sp)
	move.l	%d0,-(%sp)
	move.l	%a1,-(%sp)
	move.l	%a0,-(%sp)
	pea format
	jsr kprintf
	lea	16(%sp),%sp
	movem.l (%sp)+,%d0-%d1/%a0-%a1
0:
#endif

	subq.l #4,%d0		// size is 4.b less than actual
	bls.b ism4or0		// if d0<=0
prem4:
	cmp.l #256-4,%d0	// min size for bigmove loop, less than 128 is dangerous!
	bcc.b bigmov
m4loop:
	move.l (%a0)+,(%a1)+
	move.l (%a0)+,(%a1)+
	subq.w #8,%d0			// 8 less bytes to MOVE
	bhi.b m4loop			// if d0>0
ism4or0:
	beq.b lastm4
	rts
lastm4:
	move.l (%a0),(%a1)
	rts

	.balign 4
lastloop:
	move.l (%a0)+,(%a1)+
	subq.w #4,%d0
	bhi.b lastloop			// if d0>=0
	rts

	.balign 4
bigmov:
	moveq #128-4,%d1
	sub.l %d1,%d0				// size is now 128 less than actual
	addq.l #4,%d1			// d1=128=bytes to move per loop
bigmov4:
	move.l (%a0)+,(%a1)+
	move.l (%a0)+,(%a1)+
	move.l (%a0)+,(%a1)+
	move.l (%a0)+,(%a1)+
	move.l (%a0)+,(%a1)+
	move.l (%a0)+,(%a1)+
	move.l (%a0)+,(%a1)+
	move.l (%a0)+,(%a1)+
	move.l (%a0)+,(%a1)+
	move.l (%a0)+,(%a1)+
	move.l (%a0)+,(%a1)+
	move.l (%a0)+,(%a1)+
	move.l (%a0)+,(%a1)+
	move.l (%a0)+,(%a1)+
	move.l (%a0)+,(%a1)+
	move.l (%a0)+,(%a1)+
	move.l (%a0)+,(%a1)+
	move.l (%a0)+,(%a1)+
	move.l (%a0)+,(%a1)+
	move.l (%a0)+,(%a1)+
	move.l (%a0)+,(%a1)+
	move.l (%a0)+,(%a1)+
	move.l (%a0)+,(%a1)+
	move.l (%a0)+,(%a1)+
	move.l (%a0)+,(%a1)+
	move.l (%a0)+,(%a1)+
	move.l (%a0)+,(%a1)+
	move.l (%a0)+,(%a1)+
	move.l (%a0)+,(%a1)+
	move.l (%a0)+,(%a1)+
	move.l (%a0)+,(%a1)+
	move.l (%a0)+,(%a1)+
	sub.l	%d1,%d0				// d0=d0-128
	bcc.b	bigmov4			// if d0>=0
	add.l %d1,%d0				// d0=d0+128, back to positive
	bne.b lastloop
	rts

#if UNALIGNEDWARNING
format:
	.string "CopyMemQuick(%p,%p,%08x) unaligned size\n"
#endif
#else
	lsr.l #2,%d0		//
	beq   exit

	.short 0x0809,0x0002	//	btst   #2,%a1	
	beq    aligned
	move.l (%a0)+,(%a1)+
	subq.l	#1,%d0
aligned:

	move.l	%d0,%d1
	and.l	#3,%d0
	lsr.l	#2,%d1
        beq	zend

loop:
	move16 (%a0)+,(%a1)+
	subq.l #1,%d1
	bne.b  loop
	bra    zend
zloop:
	move.l (%a0)+,(%a1)+
zend:	dbra   %d0,zloop

exit:	rts
#endif
