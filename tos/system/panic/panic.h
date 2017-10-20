/*
 * Copyright (c) 2017 Eric B. Decker
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 *
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/*
 * Panic Subsystem.
 *
 * See doc/06_Panic_CrashDumps for more details.
 *
 * Panic.panic will typically cause a panic crashdump to be written
 * to mass storage.  The system will then reboot.
 *
 * Panic.warn on the other hand, will post an entry to the Data Stream
 * and continue on.  No reboot occurs.
 */


#ifndef __PANIC_H__
#define __PANIC_H__

#include <image_info.h>

#define PANIC_WARN_FLAG 0x80

/*
 * pcodes are used to denote what subsystem failed.  See
 * (main tree) tos/interfaces/Panic.nc for more details.
 *
 * Pcodes can be defined automatically using unique or
 * can be hard coded.   To avoid collisions, hard coded
 * pcodes start at PANIC_HC_START.  (HC = hard coded)
 *
 * Automatic pcodes start at 0 and go to 15 (0xf).  There is
 * no checking for overrun with PANIC_HC_START.  Automatics
 * are generated using unique(UQ_PANIC_SUBSYS).
 */
#define PANIC_HC_START 16

/*
 * main system hardcoded (HC) pcodes start at 0x70
 *
 * EXC          exception handler
 * KERN         kernel panics
 * DVR          undifferentiated driver panics
 */

enum {
  __pcode_exc  = 0x70,
  __pcode_kern = 0x71,
  __pcode_dvr  = 0x72,
};

#define PANIC_EXC  __pcode_exc
#define PANIC_KERN __pcode_kern
#define PANIC_DVR  __pcode_dvr

/* the argument type for panics */
typedef unsigned int parg_t;

/*
 * Various signatures for the different pieces of Panic information
 */
#define PANIC_INFO_SIG  0x44665041
#define PANIC_CRASH_SIG 0x44664352
#define PANIC_ADDITIONS 0x44664144

#define PANIC_DIR_SIG    0xDDDDB00B
#define PANIC_BLOCK_SIZE 150

typedef struct {
  uint32_t panic_dir_sig;
  uint32_t panic_block_sector;        /* dir - sector for next block */
  uint32_t panic_dir_checksum;
} panic_dir_t;

typedef struct {
  uint32_t sig;
  uint32_t ts;
  uint32_t cycle;
  uint8_t  subsys;
  uint8_t  where;
  uint16_t pad;
  uint32_t arg[4];
} panic_info_t;

/* see mm/include/image_info.h for IMAGE_INFO */

/* bx - before exception, ax - after exception */
typedef struct {
  uint32_t sig;
  uint32_t flags;
  uint32_t bxRegs[13];
  uint32_t bxSP;
  uint32_t bxLR;
  uint32_t bxPC;
  uint32_t bxPSR;                   /* Before eXception processor status */
  uint32_t axPSR;                   /* After eXception processor status */
  uint32_t fpscr;                   /* floating point status/control reg */
  uint32_t fpRegs[32];              /* floating point registers */
  uint32_t fault_regs[6];           /* SHCSR CFSR HFSR DFSR MMFAR BFAR */
} crash_info_t;

typedef struct {
  uint32_t sig;
  uint32_t ram_sector;                  /* starting sector for RAM dump, 64K */
  uint32_t io_sector;                   /* starting sector for I/O dump */
  uint32_t Fcrumb_start;                /* Flash crumbs */
} panic_additional_t;


typedef struct {
  panic_info_t          panic_info;
  image_info_t          image_info;
  crash_info_t          crash_info;
  panic_additional_t    additional_info;
} panic_block_0_t;                      /* initial sector of a panic block */


#endif /* __PANIC_H__ */
