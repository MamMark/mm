/*
 * Copyright (c) 2017 Eric B. Decker, Miles Maltbie
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
 * Various defines defining (go figure) what the Panic Block
 * looks like.  All numbers in sectors.  Each sector 512 bytes.
 *
 * HOME_BLOCK starts at 0 and goes for HOME_SIZE
 * RAM starts at (HOME_BLOCK + HOME_SIZE)
 */

#define PBLK_SIZE      150
#define PBLK_HOME      0
#define PBLK_HOME_SIZE 1
#define PBLK_RAM       1
#define PBLK_RAM_SIZE  (64 * 1024 / 512)


/*
 * IO sectors start after RAM and can grow up to 13 sectors
 * given PBLK_SIZE of 150.  If IO collides with FCRUMBS you
 * will have to bump PBLK_SIZE up.  This has to be hand
 * checked.
 */
#define PBLK_IO        (PBLK_RAM + PBLK_RAM_SIZE)

/* Flash Crumbs currently defined to be 4KiB (8 sectors) */
#define PBLK_FCRUMBS   (PBLK_SIZE - PBLK_FCRUMBS_SIZE)
#define PBLK_FCRUMBS_SIZE 8


#define PANIC_DIR_SIG    0xDDDDB00B

typedef struct {
  uint32_t panic_dir_sig;
  /*
   * dir is the 1st sector of the PANIC file, high is the inclusive
   * upper limit.  block_sector absolute block num of the next panic
   * block to write.  If block_sector is 0, the PANIC file is full
   */
  uint32_t panic_dir;                   /* limits of panic file, absolute */
  uint32_t panic_high;                  /* upper limit, inclusive         */
  uint32_t panic_block_sector;          /* where next panic block         */
  uint32_t panic_block_size;            /* size of each panic block       */
  uint32_t panic_dir_checksum;
} panic_dir_t;

typedef struct {
  uint32_t start;
  uint32_t end;
} cc_region_header_t;


#define PANIC_INFO_SIG  0x44665041

typedef struct {
  uint32_t sig;
  uint32_t boot_count;
  uint64_t systime;
  uint8_t  subsys;
  uint8_t  where;
  uint16_t pad;
  uint32_t arg[4];
} panic_info_t;


/* see mm/include/image_info.h for IMAGE_INFO */


/*
 * Crash Info is part of what is needed by CrashDebug
 * to analyze the Panic.
 *
 * The combination of CrashInfo, RAM, and IO make up what needs
 * to be fed to CrashDebug.
 *
 * CrashInfo is two parts, the first part is additional information
 * that we save.  The second part is what CrashCatcher needs to feed
 * to CrashDebug.  It starts at cc_sig on.
 *
 * We make sure that CrashCatcherInfo, RamHeader, RAM, and IO are all
 * contiguous so that the extractor can pull from the resultant
 * file easily and feed it to CrashDebug.
 *
 * If CrashInfo changes, the alignment_pad in the panic_block_0
 * structure needs to be evaluated such that the crash_info and
 * ram_header align perfectly on the end of the sector buffer.
 *
 * bx - before exception
 * ax - after exception
 */

#define CRASH_INFO_SIG          0x4349B00B
#define CRASH_CATCHER_SIG       0x63430200
#define FLAGS_FP_PRESENT        (1 << 0)

/*
 * STACK_ADJUST is the modifier to tweak the captured SP value to
 * point at the top of the stack when the fault occured.
 *
 * It modifies old_sp and includes the exception frame (r0-r3, r12,
 * LR, PC, PSR), 8 words and we add PRIMASK, BASEPRI, FAULTMASK, and
 * CONTROL.  Another 4 words for a total of 12 words.
 */
#define STACK_ADJUST            (12 * 4)

typedef struct {
  uint32_t ci_sig;                      /* crash info signature */
  uint32_t axLR;
  uint32_t MSP;
  uint32_t PSP;
  uint32_t primask;
  uint32_t basepri;
  uint32_t faultmask;
  uint32_t control;
  uint32_t cc_sig;                      /* crash catcher sig */
  uint32_t flags;
  uint32_t bxRegs[13];                  /* R0 - R12 */
  uint32_t bxSP;                        /* incoming stack pointer        */
  uint32_t bxLR;                        /* incoming Link Register        */
  uint32_t bxPC;
  uint32_t bxPSR;                       /* BX Processor Status           */
  uint32_t axPSR;                       /* AX Processor Status           */
  uint32_t fpRegs[32];                  /* floating point registers      */
  uint32_t fpscr;                       /* floating point status/control */
} crash_info_t;


#define PANIC_ADDITIONS 0x44664144

typedef struct {
  uint32_t sig;                         /* panic_additions sig */
  uint32_t ram_sector;                  /* starting sector for RAM dump, 64K */
  uint32_t ram_size;                    /* in bytes */
  uint32_t io_sector;                   /* starting sector for I/O dump */
  uint32_t fcrumb_sector;               /* flash crumbs */
} panic_additional_t;


typedef struct {
  panic_info_t          panic_info;
  image_info_t          image_info;
  panic_additional_t    additional_info;

  /*
   * set alignment_pad such that crash_info/ram_header are physically
   * at the end of panic_block_0.  You have to check the alignment of
   * ram_header.  We have seen the compiler pad out the structure at
   * the end and this will give a size of 512 (0x200) but ram_header
   * won't be physically at the end.
   */
  uint32_t              alignment_pad[14];

  /*
   * crash_info and ram_header need to be contiguous and need to
   * be at the end of the panic_block_0.
   */
  crash_info_t          crash_info;
  cc_region_header_t    ram_header;
} panic_block_0_t;                      /* initial sector of a panic block */


#endif /* __PANIC_H__ */
