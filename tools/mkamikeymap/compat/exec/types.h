#ifndef MKAKM_COMPAT_EXEC_TYPES_H
#define MKAKM_COMPAT_EXEC_TYPES_H

#include <stdint.h>

typedef void *APTR;
typedef int32_t LONG;
typedef uint32_t ULONG;
typedef int16_t WORD;
typedef uint16_t UWORD;
typedef int8_t BYTE;
typedef uint8_t UBYTE;
typedef uintptr_t IPTR;
typedef intptr_t SIPTR;
typedef short BOOL;

#ifndef FALSE
#define FALSE 0
#endif
#ifndef TRUE
#define TRUE 1
#endif

#ifndef __packed
#define __packed __attribute__((packed))
#endif

#endif
