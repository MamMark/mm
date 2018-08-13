/*
 * Copyright (c) 2017-2018 Eric B. Decker, Miles Maltbie
 * Copyright (c) 2018, Eric B. Decker
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
#include <rtctime.h>
#include <platform_panic.h>
#include <overwatch.h>

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
 *
 * platform_panic.h MUST define __pcode_{exc,kern,dvr} and
 * the associated defines PANIC_{EXC,KERN,DVR}.  We check
 * for the existence of PANIC_EXC and yell if not found.
 * Yes, Margaret, its fatal.
 */

/*
 * main system hardcoded (HC) pcodes start at 0x70
 *
 * EXC          exception handler
 * KERN         kernel panics
 * DVR          undifferentiated driver panics
 */

#ifndef PANIC_EXC
#error PANIC_EXC and friends need to defined in platform_panic.h
#endif

/* the argument type for panics */
typedef unsigned int parg_t;


/*
 * Panic Area Structure...
 *
 * The Panic Area stores panics.  Each panic is stored in one Panic Block.
 * The 1st sector of the Panic Area is the Panic Dir, which stores
 * information about the Panic Area (see panic_dir_t).  If the Panic Dir
 * sector is completely empty it denotes no panics have been written and
 * initial values will be used.
 *
 * Structure of a Panic Block.
 *
 * When a panic occurs, we want to save the current machine state, this
 * consists of RAM (64KB), various I/O registers, and the cpu state at
 * the time of the Panic or Exception.
 *
 * A Panic Block is currently limited to 150 sectors.  The Panic Block
 * has the following format:
 *
 * The first two sectors contain panic headers and describe what happened
 * (panic_hdr0 and panic_hdr1).
 *
 * panic_hdr0:
 *      panic_info.pi_sig   signature identifying hdr 0
 *      panic_info:         base address of the image
 *                          timestamp of the panic
 *                          panic information (pcode, where, args)
 *      owcb_info:          copy of the control block at the time of the
 *                          panic.  Panic cause information, resets, etc.
 *      image_info:         descriptor of the image that failed
 *      additional_info:    file offsets/size of areas in the panic block
 *      ph0_checksum:       checksum over hdr0
 *
 * panic_hdr1:
 *      ph1_sig:            signature identifying hdr 1
 *      ph0_offset:         redundant, offset verification
 *      ph1_offset:         redundant, offset verification
 *      ph1_checksum:       checksum over hdr1
 *      ram_checksum:       checksum over ram region
 *      io_checksum:        checksum over i/o area
 *      crash_info:         CrashDebug compatible machine state
 *      ram_header:         ram area header.
 *
 * Following the panic header is a 128 sector region  containing the
 * full 64K RAM contents.  It is described by the ram_header at the end
 * of panic_hdr1.  It must be physically at the end of the sector.
 *
 * Following the RAM section is a 12 sector (6KB) I/O region.  Each I/O
 * region in the I/O secton is described by region discriptor immediately
 * preceeding the region.
 *
 * The last area of the Panic Block is a 4KB (8 sector) area reserved for
 * Flash Crumbs (FCrumbs).  Currently not implemented.
 */

/*
 * Various defines defining (go figure) what the Panic Block
 * looks like.  All numbers in sector units.  These are deltas
 * from the start of the panic block.  Each sector 512 bytes.
 *
 * ZERO_BLOCK starts at 0 and goes for ZERO_SIZE
 * RAM starts at (ZERO_BLOCK + ZERO_SIZE)
 *
 * See doc/06_Panic_CrashDumps for how the 150 was arrived at.
 */

#define PBLK_SIZE      150
#define PBLK_ZERO      0
#define PBLK_ZERO_SIZE 2
#define PBLK_RAM       2
#define PBLK_RAM_SIZE  (64 * 1024 / 512)


/*
 * IO sectors start after RAM and can grow up to 12 sectors
 * given PBLK_SIZE of 150.  If IO collides with FCRUMBS you
 * will have to bump PBLK_SIZE up.  This has to be hand
 * checked.
 */
#define PBLK_IO        (PBLK_RAM + PBLK_RAM_SIZE)

/* Flash Crumbs currently defined to be 4KiB (8 sectors) */
#define PBLK_FCRUMBS   (PBLK_SIZE - PBLK_FCRUMBS_SIZE)
#define PBLK_FCRUMBS_SIZE 8


#define PANIC_DIR_SIG    0xDDDDB00B
#define PANIC_ID_SIZE    4


/*
 * dir_id:      human readable sig
 *
 * dir_sig:     directory signature, majik number.
 *
 * dir_sector:  1st sector of the PANIC file
 *
 * high_sector: inclusive upper limit of the panic area.
 *
 * block_index: index of the next panic block index to write.  Also the
 *              number of panics that have been written.  (starts at 0).
 *
 * block_index_max: the highest index + 1.  ie.  if we have room for 32
 *              panics, this value will be 32.  block_index shouldn't be
 *              above this. If block_index >= max then we are full.
 *
 * block_size:  size of a panic block in sectors.
 *
 * dir_checksum:a 32 bit checksum over the entire panic dir.  Should sum
 *              to 0.
 */
typedef struct {
  uint8_t  panic_dir_id[PANIC_ID_SIZE]; /* PANI */
  uint32_t panic_dir_sig;
  uint32_t panic_dir_sector;            /* limits of panic file, absolute */
  uint32_t panic_high_sector;           /* upper limit, inclusive         */
  uint32_t panic_block_index;           /* next panic block to write      */
  uint32_t panic_block_index_max;       /* upper limit of indicies        */
  uint32_t panic_block_size;            /* size of each panic block       */
  uint32_t panic_dir_checksum;
} panic_dir_t;

typedef struct {                        /* memory addresses */
  uint32_t start;
  uint32_t end;
} cc_region_header_t;


#define PANIC_INFO_SIG  0x44665041

typedef struct {                        /* verify all structs in PIX */
  uint32_t     pi_sig;
  uint32_t     base_addr;               /* base addr of image dieing */
  rtctime_t    rt;                      /* time of crash */
  uint8_t      pi_pcode;                /* panic information */
  uint8_t      pi_where;
  uint32_t     pi_arg0;
  uint32_t     pi_arg1;
  uint32_t     pi_arg2;
  uint32_t     pi_arg3;
} panic_info_t;


/* see include/image_info.h for IMAGE_INFO */


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
  uint32_t ai_sig;                      /* panic_additions sig */
  uint32_t ram_offset;                  /* starting file offset for RAM dump */
  uint32_t ram_size;                    /* 64 KiB (bytes) */
  uint32_t io_offset;                   /* starting file offset for I/O dump */
  uint32_t fcrumb_offset;               /* flash crumb, file offset          */
} panic_additional_t;


/*
 * Panic Header Structures.
 * each structure is required to be exactly 512 bytes.
 *
 * Signatures.  Each panic header starts with an identifing signature.
 * panic_hdr0 starts with the panic_info.pi_sig (PANIC_INFO_SIG).  And
 * panic_hdr1 starts with ph1_sig (PANIC_HDR1_SIG).
 *
 * panic_hdr0 includes image_info, the plus section of image_info has been
 * sized to make hdr0 512 bytes.
 *
 * ph0_checksum is a 32 bit byte checksum of all bytes in hdr0 excluding
 * the ph0_checksum.  The checksum is computed with ph0_checksum set to 0.
 * That ph0_checksum is an external checksum.
 *
 * panic_hdr1 includes the crash_info (machine state needed for CrashDebug)
 * and the ram_header for the following RAM section.  ram_head must be
 * physically at the end of the panic_hdr1 sector.  That is contiguous with
 * the start of the RAM section.
 *
 * ram_checksum is a 32 bit byte checksum over all the bytes in the Ram
 * section.  It is computed on the fly as the Ram sectors are written out
 * to the panic block.
 *
 * io_checksum similarly is the external checksum over all i/o section bytes.
 * this includes an i/o section headers.
 *
 * ph1_checksum is the external checksum over the entire panic_hdr1 sector
 * after all other checksums have been computed.  the panic_hdr1 sector is
 * inital written out with the checksum zero'd, then read back in, the
 * checksums get filled in, and the final sector written out.
 */

typedef struct {
  panic_info_t          panic_info;
  ow_control_block_t    owcb_info;
  image_info_t          image_info;     /* for binary identification */
  panic_additional_t    additional_info;
  uint32_t              ph0_checksum;           /* external sum   */
} panic_hdr0_t;                /* initial sector of a panic block */


#define PANIC_HDR1_SIG  0x44665999

typedef struct {
  /*
   * set alignment_pad such that crash_info/ram_header are physically
   * at the end of panic_block_0.  You have to check the alignment of
   * ram_header.  We have seen the compiler pad out the structure at
   * the end and this will give a size of 512 (0x200) but ram_header
   * won't be physically at the end.
   */
  uint32_t              ph1_sig;
  uint16_t              core_rev;
  uint16_t              core_minor;
  uint32_t              alignment_pad[58];

  uint32_t              ph0_offset;     /* redundant offset     */
  uint32_t              ph1_offset;     /* redundant offset     */
  uint32_t              ph1_checksum;   /* external sum         */
  uint32_t              ram_checksum;   /* sum over ram section */
  uint32_t              io_checksum;    /* sum over io section  */

  /*
   * crash_info and ram_header need to be contiguous and need to
   * be at the end of the panic_zero_1.
   */
  crash_info_t          crash_info;
  cc_region_header_t    ram_header;
} panic_hdr1_t;                       /* crash info and ram header. */


#endif /* __PANIC_H__ */
