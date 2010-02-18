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

#define _UINT32_T
#define __uint32_t_defined
typedef unsigned long  uint32_t;
#include <stdint.h>

typedef int bool_t;
typedef signed char __s8;
typedef unsigned char __u8;
typedef unsigned char u8_t;

typedef signed short __s16;
typedef unsigned short __u16;
typedef unsigned short u16_t;

typedef signed long __s32;
typedef unsigned long __u32;
typedef unsigned long u32_t;

typedef signed long long __s64;
typedef unsigned long long __u64;
typedef unsigned long long u64_t;

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
