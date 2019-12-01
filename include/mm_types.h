/* $Id: mm_types.h,v 1.13 2007/09/10 21:04:42 cire Exp $ */
/*
  Basic types for files built in the mam_mark system.
*/

#ifndef _MM_TYPES_H
#define _MM_TYPES_H

#ifdef notdef
 #ifndef __IAR_SYSTEMS_ICC__
 #define __monitor
 #endif

 #define __READ const
 #define PACKED __attribute__((__packed__))
#endif

#include <stdint.h>

typedef struct{
  uint8_t bit0       : 1;
  uint8_t bit1       : 1;
  uint8_t bit2       : 1;
  uint8_t bit3       : 1;
  uint8_t bit4       : 1;
  uint8_t bit5       : 1;
  uint8_t bit6       : 1;
  uint8_t bit7       : 1;
} bitwise_t;

typedef int         bool_t;
typedef int8_t      __s8;
typedef uint8_t     __u8;
typedef uint8_t     u8_t;

typedef int16_t     __s16;
typedef uint16_t    __u16;
typedef uint16_t     u16_t;

typedef int32_t     __s32;
typedef uint32_t    __u32;
typedef uint32_t    u32_t;

typedef int64_t     __s64;
typedef uint64_t    __u64;
typedef uint64_t    u64_t;

#define TRUE  1
#define FALSE 0

#ifdef notdef
#define ON    1
#define OFF   0

#undef NULL
#define NULL ((void *)0)

#define min(a, b) ((a) < (b) ? (a) : (b))

#endif

#endif /* _MM_TYPES_H */
