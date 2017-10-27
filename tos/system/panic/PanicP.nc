/*
 * Copyright (c) 2012-2013, 2016-2017 Eric B. Decker
 * Copyright (c) 2017 Miles Maltbie, Eric B. Decker
 * All rights reserved.
 *
 * This module provides a full Panic implementation.
 *
 * Panic is responsible for collecting crash information and saving
 * it to persistent storage.  One crash set is called a Panic Block
 * and is written to one section of the Panic Region/Area on the SD.
 *
 * See doc/06_Panic_CrashDumps for more details.
 *
 * PANIC_WIGGLE: enables code to wiggle the EXC (exception) signal
 * line with information about what panic occurred.
 */

#include <platform.h>
#include <panic.h>
#include <panic_regions.h>
#include <sd.h>
#include <fs_loc.h>

#ifdef PANIC_GATE
uint32_t g_panic_gate;
#endif

#ifdef   PANIC_WIGGLE
#ifndef  WIGGLE_EXC
#warning WIGGLE_EXC not defined, using default nothingness
#define  WIGGLE_EXC do{} while (0)
#define  WIGGLE_DELAY 1
#endif
#endif

#ifdef notdef
#ifdef PANIC_DINT
#define MAYBE_SAVE_SR_AND_DINT	do {	\
    if (save_sr_free) {			\
      save_sr = READ_SR;		\
      save_sr_free = FALSE;		\
    }					\
    dint();				\
} while (0);
#else
#define MAYBE_SAVE_SR_AND_DINT	do {} while (0)
#endif
#endif

#define PCB_SIG 0xAAAAB00B;

typedef struct {
  uint32_t pcb_sig;

  /* if a double panic, high order bit is set */
  uint32_t in_panic;           /* initialized to 0 */

  /* persistent state for collect_io */
  uint8_t *buf;                /* inits to NULL */
  uint8_t *bptr;
  uint32_t remaining;          /* inits to 0 */
  uint32_t block;              /* where the block starts */
  uint32_t panic_sec;          /* current sector being written */

  /* panic control, only active after a Panic happens */
  uint32_t dir;                /* directory sector */
  uint32_t low;                /* low  limit for blocks */
  uint32_t high;               /* high limit for blocks */
  uint32_t pcb_sum;            /* checksum */
} pcb_t;

norace pcb_t pcb;              /* panic control block */
norace panic_dir_t panic_dir;

module PanicP {
  provides {
    interface Panic;
    interface Init;
  }
  uses {
    interface SSWrite  as SSW;
    interface Platform;
    interface FileSystem as FS;
    interface OverWatch;
    interface SDsa;                     /* standalone */
    interface SDraw;                    /* other SD aux */
    interface Checksum;
  }
}

implementation {
  parg_t save_sr;
  bool save_sr_free;
  norace uint8_t _p, _w;
  norace parg_t _a0, _a1, _a2, _a3, _arg;

#ifdef PANIC_WIGGLE
  void debug_break(parg_t arg)  __attribute__ ((noinline)) {
    uint32_t t0;
    uint32_t i;

    _arg = arg;
    WIGGLE_EXC; WIGGLE_EXC; WIGGLE_EXC; WIGGLE_EXC;     /* 4 */
    t0 = call Platform.usecsRaw();
    while ((call Platform.usecsRaw() - t0) < WIGGLE_DELAY) ;

    for (i = 0; i < _p; i++)
      WIGGLE_EXC;
    t0 = call Platform.usecsRaw();
    while ((call Platform.usecsRaw() - t0) < WIGGLE_DELAY) ;

    for (i = 0; i < _w; i++)
      WIGGLE_EXC;
    t0 = call Platform.usecsRaw();
    while ((call Platform.usecsRaw() - t0) < WIGGLE_DELAY) ;
    WIGGLE_EXC; WIGGLE_EXC; WIGGLE_EXC; WIGGLE_EXC;     /* 4 */

    nop();                              /* BRK */
    ROM_DEBUG_BREAK(0xf0);
  }
#else
  void debug_break(parg_t arg)  __attribute__ ((noinline)) {
    _arg = arg;
    ROM_DEBUG_BREAK(0xf0);
  }
#endif

  void update_pcb() {
    pcb.pcb_sig   = PCB_SIG;
    pcb.buf       = call SSW.get_temp_buf();
    pcb.bptr      = pcb.buf;
    pcb.remaining = SD_BLOCKSIZE;

    pcb.dir       = call FS.area_start(FS_LOC_PANIC);
    pcb.low       = pcb.dir + 1;
    pcb.high      = call FS.area_end(FS_LOC_PANIC);
    pcb.block     = pcb.low;
    pcb.panic_sec = pcb.block;
  }

  void init_panic_dump() {
    panic_dir_t *dirp;

    /*
     * at some point
     *
     * FS.reload_locator_sa() fail -> strange
     * get panic region start/end
     * initialize the dir, low, high
     *
     * get a buffer.
     * read the dir
     * if the dir sector is zeros panic_sec = dir+1
     * else verify dir, passes panic_sec = next_block_start
     *    doesn't pass strange
     *
     * initialize buffer management
     */

    /*
     * FS.reload_locator_sa will turn on the SD
     * we don't need to do a SDsa.reset(), its been done.
     */
    if (call FS.reload_locator_sa(pcb.buf))
      call OverWatch.strange(0x80);     /* no return */
    update_pcb();

    call SDsa.read(pcb.dir, pcb.buf);
    dirp = (panic_dir_t *) pcb.buf;

    /* this will get changed to chk_zero when refactored */
    /* call SDraw.chk_zero(pcb.buf, SD_BLOCKSIZE)) */
    if (!call SDraw.chk_zero(pcb.buf, SD_BLOCKSIZE)) {
      /* validate dir, fails -> strange */
      if (dirp->panic_dir_sig != PANIC_DIR_SIG) {
        call OverWatch.strange(0x81);

        /* Otherwise we read in the dir */
        pcb.block = dirp->panic_block_sector;
        pcb.panic_sec = pcb.block;
      } /*else  Directory is zeroed. continue and write out dir */
    }
  }

  void panic_write(uint32_t blk_id, uint8_t *buf) {
      if (panic_dir.panic_dir_sig != PANIC_DIR_SIG
          || blk_id < pcb.low
          || blk_id  > pcb.high) {
        call OverWatch.strange(0x82);
      }
      call SDsa.write(blk_id, buf);
    }

  void update_panic_dir() {
    panic_dir_t *dirp;

    /*
     * need to bump pcb.block to the next panic block if any.
     * pcb.block += PANIC_BLOCK_SIZE
     */
    dirp                     = (panic_dir_t *) pcb.buf;
    dirp->panic_dir_sig      = PANIC_DIR_SIG;
    dirp->panic_block_sector = pcb.block + PANIC_BLOCK_SIZE;
    dirp->panic_dir_checksum = 0;
    dirp->panic_dir_checksum = 0 - call Checksum.sum32_aligned((void *) dirp, sizeof(*dirp));

    panic_write(pcb.dir, pcb.buf);
    call SDsa.off();
  }


  void collect_ram(const panic_region_t *ram_desc) {
    uint32_t len = ram_desc->len;
    uint8_t *base = ram_desc->base_addr;

    while (len > 0) {
      panic_write(pcb.panic_sec, base);
      pcb.panic_sec++;
      base += 512;
      len  -= 512;
    }
  }


  /*
   * copy the region pointed at by src into the working buffer at dest
   * return where we left off.
   *
   * input: src         where we are coping from
   *        len         how many bytes are being copied
   *        esize       element size, granularity
   *                    1 - byte granules
   *                    2 - half word (16 bit) granules
   *                    4 - word (32 bit) granules
   *                    granuals > 1 have to be properly aligned.
   *
   * data moved should be properly aligned for the granual as well
   * as have a modulo granual length.
   */
  void copy_region(uint8_t *src, uint32_t len, uint32_t esize)  {
    uint8_t *dest;
    uint32_t d_len, copy_len, w_len;
    uint16_t *dp_16, *sp_16;
    uint32_t *dp_32, *sp_32;

    dest = pcb.bptr;
    d_len = pcb.remaining;

    /* protect len against non-granular values */
    len = (len + (esize - 1)) & ~(esize - 1);
    while (len > 0) {
      copy_len = ((len < d_len) ? len : d_len);
      w_len    = copy_len;
      switch (esize) {
        default:
        case 1:
          while (w_len) {
            *dest++ = *src++;
            w_len--;
          }
          break;

        case 2:
          dp_16 = (void *) dest;
          sp_16 = (void *) src;
          while (w_len) {
            *dp_16++ = *sp_16++;
            w_len -= 2;
          }
          break;

        case 4:
          dp_32 = (void *) dest;
          sp_32 = (void *) src;
          while (w_len) {
            *dp_32++ = *sp_32++;
            w_len -= 4;
          }
          break;
      }
      src   += copy_len;
      len   -= copy_len;
      dest  += copy_len;
      d_len -= copy_len;
      if (!d_len) {
        /*
         * current sd buffer is full, need to write it out and
         * reset the buffer pointers.
         */

        panic_write(pcb.panic_sec, pcb.buf);
        pcb.panic_sec++;
        dest = pcb.buf;
        d_len = SD_BLOCKSIZE;
      }
      pcb.bptr = dest;
      pcb.remaining = d_len;
    }
  }


  void collect_io(const panic_region_t *io_desc) {
    while (io_desc->base_addr != PR_EOR) {
      copy_region((void *)io_desc, sizeof(panic_region_t), 4);
      copy_region(io_desc->base_addr, io_desc->len, io_desc->element_size);
      io_desc++;
    }
    if (pcb.remaining != SD_BLOCKSIZE) {
      call SDraw.zero_fill((uint8_t *)pcb.buf, SD_BLOCKSIZE - pcb.remaining);
      panic_write(pcb.panic_sec, pcb.buf);
    }
  }


  async command void Panic.warn(uint8_t pcode, uint8_t where,
        parg_t arg0, parg_t arg1, parg_t arg2, parg_t arg3)
        __attribute__ ((noinline)) {

    pcode |= PANIC_WARN_FLAG;

    _p = pcode; _w = where;
    _a0 = arg0; _a1 = arg1;
    _a2 = arg2; _a3 = arg3;

//    MAYBE_SAVE_SR_AND_DINT;
    debug_break(0);
  }


  /*
   * Panic.panic: something really bad happened.
   * Simple version.   Do nothing allow debug break.
   */

  async command void Panic.panic(uint8_t pcode, uint8_t where,
        parg_t arg0, parg_t arg1, parg_t arg2, parg_t arg3)
        __attribute__ ((noinline)) {

    _p = pcode; _w = where;
    _a0 = arg0; _a1 = arg1;
    _a2 = arg2; _a3 = arg3;
    debug_break(1);
    if (pcb.in_panic) {
      pcb.in_panic |= 0x80;             /* flag a double */
      ROM_DEBUG_BREAK(0xf1);
      call OverWatch.strange(0x83);     /* no return */
    }

    pcb.in_panic = TRUE;
    signal Panic.hook();

    /*
     * initialize for writing panic information out to
     * the PANIC area.
     */
    nop();                              /* BRK */
    ROM_DEBUG_BREAK(0xf0);
    init_panic_dump();
    collect_ram(&ram_region);
    collect_io(&io_regions[0]);
    update_panic_dir();
    ROM_DEBUG_BREAK(0xf0);

#ifdef PANIC_GATE
    while (g_panic_gate != 0xdeadbeaf) {
      nop();
    }
#endif
    call OverWatch.fail(ORR_PANIC);
    /* shouldn't return */
    call OverWatch.strange(0x84);       /* no return */
  }


  command error_t Init.init() {
    save_sr_free = TRUE;
    save_sr = 0xffff;
    return SUCCESS;
  }


  event void FS.eraseDone(uint8_t which) { }

  default async event void Panic.hook() { }
}
