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


bool chk_zero(uint8_t *buf, uint32_t len) {
  uint32_t *p;

  p = (void *) buf;
  while (1) {
    if (*p++) return FALSE;
    len -= 4;
    if (len < 3)
      break;
  }
  if (!len) return TRUE;
  if (*p & (0xffffffff >> ((4 - len) * 8)))
    return FALSE;
  return TRUE;
}

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
  }
}

implementation {
  parg_t save_sr;
  bool save_sr_free;
  norace uint8_t _p, _w;
  norace parg_t _a0, _a1, _a2, _a3, _arg;

  /* if a double panic, high order bit is set */
  norace bool m_in_panic;       /* initialized to 0 */

  /* persistent state for collect_io */
  norace uint8_t *m_buf;                /* inits to NULL */
  norace uint8_t *m_bptr;
  norace uint32_t m_remaining;          /* inits to 0 */
  norace uint32_t m_block;              /* where the block starts */
  norace uint32_t m_panic_sec;          /* current sector being written */

  /* panic control, only active after a Panic happens */
  norace uint32_t m_dir;                /* directory sector */
  norace uint32_t m_low;                /* low  limit for blocks */
  norace uint32_t m_high;               /* high limit for blocks */

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


  void init_panic_dump() {
    panic_dir_t *dirp;

    /*
     * at some point
     *
     * FS.reload_locator_sa() fail -> strange
     * get panic region start/end
     * initialize the m_dir, m_low, m_high
     *
     * get a buffer.
     * read the dir
     * if the dir sector is zeros m_panic_sec = m_dir+1
     * else verify dir, passes m_panic_sec = next_block_start
     *    doesn't pass strange
     *
     * initialize buffer management
     */

    m_buf = call SSW.get_temp_buf();
    m_remaining = SD_BLOCKSIZE;

    /*
     * FS.reload_locator_sa will turn on the SD
     * we don't need to do a SDsa.reset(), its been done.
     */
    if (call FS.reload_locator_sa(m_buf)) {
      /*
       * strange
       */
      while (1) {
        nop();
      }
    }
    m_dir       = call FS.area_start(FS_LOC_PANIC);
    m_low       = m_dir + 1;
    m_high      = call FS.area_end(FS_LOC_PANIC);
    m_block     = m_low;
    m_panic_sec = m_low;

    call SDsa.read(m_dir, m_buf);

    /* this will get changed to chk_zero when refactored */
    if (!dir_sec_zero) {

      /* validate dir, fails -> strange */

      dirp = (void *) m_buf;
      m_block = dirp->panic_block_sector;
      m_panic_sec = m_block;
    }
  }


  void update_panic_dir() {
    panic_dir_t *dirp;

    /*
     * need to bump m_block to the next panic block if any.
     * m_block += PANIC_BLOCK_SIZE
     */
    dirp                     = (panic_dir_t *) m_buf;
    dirp->panic_dir_sig      = PANIC_DIR_SIG;
    dirp->panic_block_sector = m_block + PANIC_BLOCK_SIZE;

    /* fix checksum */

    call SDsa.write(m_dir, m_buf);
    call SDsa.off();
  }


  void collect_ram(const panic_region_t *ram_desc) {
    uint32_t len = ram_desc->len;
    uint8_t *base = ram_desc->base_addr;

    while (len > 0) {
      call SDsa.write(m_panic_sec, base);
      m_panic_sec++;
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
    uint32_t d_len, copy_len;
    uint16_t *dp_16, *sp_16;
    uint32_t *dp_32, *sp_32;

    dest = m_bptr;
    d_len = m_remaining;

    /* protect len against non-granular values */
    len = (len + (esize - 1)) & ~(esize - 1);
    while (len > 0) {
      copy_len = ((len < d_len) ? len : d_len);
      switch (esize) {
        default:
        case 1:
          while (copy_len) {
            *dest++ = *src++;
            copy_len--;
          }
          break;

        case 2:
          dp_16 = (void *) dest;
          sp_16 = (void *) src;
          while (copy_len) {
            *dp_16++ = *sp_16++;
            copy_len -= 2;
          }
          break;

        case 4:
          dp_32 = (void *) dest;
          sp_32 = (void *) src;
          while (copy_len) {
            *dp_32++ = *sp_32++;
            copy_len -= 4;
          }
          break;
      }
      src   += copy_len;
      len   -= copy_len;
      dest  += copy_len;
      d_len -= copy_len;
      if (!d_len) {
        call SDsa.write(m_panic_sec, m_buf);
        m_panic_sec++;
        dest = m_buf;
        d_len = SD_BLOCKSIZE;
      }
    }
    m_bptr = dest;
    m_remaining = d_len;
  }


  void collect_io(const panic_region_t *io_desc) {
    while (io_desc->base_addr != PR_EOR) {
      copy_region((void *)io_desc, sizeof(panic_region_t), 4);
      copy_region(io_desc->base_addr, io_desc->len, io_desc->element_size);
      io_desc++;
    }
    if (m_remaining != SD_BLOCKSIZE)
      call SDsa.write(m_panic_sec, m_buf);
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
    if (m_in_panic) {
      m_in_panic |= 0x80;               /* flag a double */
      ROM_DEBUG_BREAK(0xf1);
      /*
       * Need to Strange here.
       */
      while (1) {
        nop();
      }
    }

    m_in_panic = TRUE;
    signal Panic.hook();

    /*
     * initialize for writing panic information out to
     * the PANIC area.
     */
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
