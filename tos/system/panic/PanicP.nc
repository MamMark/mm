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


uint8_t test_buf[512];


module PanicP {
  provides {
    interface Panic;
    interface Init;
  }
  uses {
    interface SSWrite  as SSW;
    interface SDsa;                     /* standalone */
    interface Platform;
    interface FileSystem as FS;
    interface OverWatch;
  }
}

implementation {
  parg_t save_sr;
  bool save_sr_free;
  norace uint8_t _p, _w;
  norace parg_t _a0, _a1, _a2, _a3, _arg;

  /* if a double panic, high order bit is set */
  norace bool m_in_panic;               /* initialized to 0 */

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


  void collect_ram(const panic_region_t *ram_desc, uint32_t start_sec) {
    uint32_t cur_sec = start_sec;
    uint32_t len = ram_desc->len;
    uint8_t *base = ram_desc->base_addr;

    while (len > 0) {
      call SDsa.write(cur_sec, base);
      base += 512;
      len  -= 512;
      cur_sec++;
    }
  }


  void collect_io(const panic_region_t *io_desc, uint8_t *buf, uint32_t io_sector) {
    uint8_t *src, *dst;
    uint32_t s_len, d_len, copy_len;

    dst   = buf;
    d_len = SD_BLOCKSIZE;

    while (io_desc->base_addr != PR_EOR) {
      src    = io_desc->base_addr;
      s_len  = io_desc->len;

      while (s_len) {
        copy_len = ((s_len < d_len) ? s_len : d_len);
        memcpy(dst, src, copy_len);
        src   += copy_len;
        s_len -= copy_len;
        dst   += copy_len;
        d_len -= copy_len;
        if (!d_len) {
          call SDsa.write(io_sector, buf);
          io_sector++;
          dst = buf;
          d_len = SD_BLOCKSIZE;
        }
      }
      io_desc++;
    }
    if (dst != buf) {
      /* zero end of buf */
      call SDsa.write(io_sector, buf);
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

    uint32_t panic_sec;

    _p = pcode; _w = where;
    _a0 = arg0; _a1 = arg1;
    _a2 = arg2; _a3 = arg3;
    debug_break(1);
    if (!m_in_panic) {
      /*
       * Panic.hook may call code that may cause a panic.  Don't loop
       */
      m_in_panic = TRUE;
      signal Panic.hook();
    } else
      m_in_panic |= 0x80;               /* flag a double */

    /*
     * for debugging,
     *
     * we want to call FS get regionstart for PANIC for a sector
     * call SSW.get_tmp_buf for a buffer
     */
    panic_sec = call FS.area_start(FS_LOC_PANIC);

    collect_ram(&ram_region, panic_sec);
    collect_io(&io_regions[0], test_buf, panic_sec);
    ROM_DEBUG_BREAK(0xf0);

#ifdef PANIC_GATE
    while (g_panic_gate != 0xdeadbeaf) {
      nop();
    }
#endif
    call OverWatch.fail(ORR_PANIC);
    /* shouldn't return */
    while (1) {
      nop();
    }
  }


  command error_t Init.init() {
    save_sr_free = TRUE;
    save_sr = 0xffff;
    return SUCCESS;
  }


  event void FS.eraseDone(uint8_t which) { }

  default async event void Panic.hook() { }
}
