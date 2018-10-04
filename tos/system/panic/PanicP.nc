/*
 * Copyright (c) 2012-2013, 2016-2017 Eric B. Decker
 * Copyright (c) 2017-2018 Miles Maltbie, Eric B. Decker
 * Copyright (c) 2018 Eric B. Decker
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
 */

#include <platform.h>
#include <panic.h>
#include <panic_regions.h>
#include <sd.h>
#include <fs_loc.h>
#include <overwatch.h>
#include <TinyError.h>
#include <string.h>

#ifdef PANIC_GATE
norace volatile uint32_t g_panic_gate;
#endif

#define PCB_SIG 0xAAAAB00B
#define PANIC_IN_PANIC 0xdeddb00b

/* internal structure for controlling panic */
typedef struct {
  uint32_t pcb_sig;
  uint32_t in_panic;           /* initialized to 0          */
                               /* set to 0xdeddb00b in panic*/

  /* persistent state for collect_io */
  uint8_t *buf;                /* inits to NULL */
  uint8_t *bptr;
  uint32_t remaining;          /* inits to 0 */
  uint32_t block;              /* where the block starts, abs */
  uint32_t panic_sec;          /* current sector being written, abs */

  /* panic control, only active after a Panic happens */
  uint32_t dir;                /* directory sector */
  uint32_t low;                /* low  limit for blocks */
  uint32_t high;               /* high limit for blocks */

  /* checksums when writing regions out */
  uint32_t ram_checksum;
  uint32_t io_checksum;
} pcb_t;


/*
 * structure to hold panic arguments as well as misc control registers
 * captured on the way into Panic.
 *
 * All entries on the stack are words so we make everything words as well.
 *
 * If we have a stack collision (ie. the main stack has overflowed into the
 * crash_stack) these entries will just be set to 0 (done on initilization
 * on first boot).  And pcode will be set to -1 (0xffffffff).
 */
typedef struct {
  uint32_t pcode;                       /* subsys */
  uint32_t where;
  uint32_t a0;                          /* arguments */
  uint32_t a1;
  uint32_t a2;
  uint32_t a3;
  uint32_t *old_sp;                     /* failee stack pointer  */
  uint32_t *cs_regs_sp;                 /* crash stack reg save */
} panic_args_t;


/*
 * what the old_stack looks like on entry to __panic_panic_entry
 */
typedef struct {
  uint32_t primask;
  uint32_t basepri;
  uint32_t faultmask;
  uint32_t control;
  uint32_t pcode;                       /* r0, subsys     */
  uint32_t where;                       /* r1             */
  uint32_t a0;                          /* r2, arguments  */
  uint32_t a1;                          /* r3             */
  uint32_t r12;
  uint32_t bxLR;
  uint32_t bxPC;
  uint32_t bxPSR;
  uint32_t a2;
  uint32_t a3;
} panic_old_stack_t;


/*
 * what the old_stack looks like on entry to __panic_exception_entry
 */
typedef struct {
  uint32_t primask;
  uint32_t basepri;
  uint32_t faultmask;
  uint32_t control;
  uint32_t r0;
  uint32_t r1;
  uint32_t r2;
  uint32_t r3;
  uint32_t r12;
  uint32_t bxLR;
  uint32_t bxPC;
  uint32_t bxPSR;
} exc_old_stack_t;


/*
 * what the crash_stack looks like on entry to __panic_main
 */
typedef struct {
  uint32_t axPSR;
  uint32_t PSP;
  uint32_t MSP;
  uint32_t r4;
  uint32_t r5;
  uint32_t r6;
  uint32_t r7;
  uint32_t r8;
  uint32_t r9;
  uint32_t r10;
  uint32_t r11;
  uint32_t axLR;
} panic_crash_stack_t;


extern image_info_t image_info;
extern uint32_t     __crash_stack_top__;

bool _panic_args_warn_busy;
panic_args_t _panic_args;
norace pcb_t pcb;                               /* panic control block */

uint8_t  panic_buf[SD_BLOCKSIZE] __attribute__ ((aligned (4)));

module PanicP {
  provides {
    interface Panic;
    interface PanicManager;
  }
  uses {
    interface Platform;
    interface FileSystem as FS;
    interface OverWatch;
    interface SDsa;                     /* standalone */
    interface SDraw;                    /* other SD aux */
    interface SDread;
    interface Resource as SDResource;
    interface Checksum;
    interface SysReboot;
    interface Rtc;
    interface Collect;
  }
}

implementation {

  /*
   * convert an index into a proper block
   *
   * if too big then just say max block.
   */
  uint32_t index2block(uint32_t idx) {
    uint32_t block;

    block = (idx * PBLK_SIZE) + pcb.low;
    if ((block + PBLK_SIZE) > pcb.high)
      block = pcb.high + 1;
    return block;
  }


  /*
   * convert a block to a proper index.
   *
   * if too big or too small return max index saying full
   *
   * assumes pcb has been initialized.
   * assumes blk_id points at first block of the Panic Block.
   */
  uint32_t block2index(uint32_t blk_id) {
    uint32_t idx;

    if (blk_id < pcb.low || (blk_id + PBLK_SIZE) > pcb.high)
      blk_id = pcb.high + 1;
    idx = (blk_id - pcb.low)/PBLK_SIZE;
    return idx;
  }


  /*
   * convert a Panic Block to a Panic file offset
   *
   * (block - dir) * SD_BLOCKSIZE
   *
   * dir < block <= high, otherwise return -1.
   */
  uint32_t block2offset(uint32_t blk_id) {

    if (blk_id < pcb.low || blk_id > pcb.high)
      return (uint32_t) -1;
    return (blk_id - pcb.dir) * SD_BLOCKSIZE;
  }


  /*
   * init_pcb:  set up the panic control block.
   *
   * buf:       a buffer that holds the directory sector and will be used
   *            for future read/writes in the panic system.
   * start/end: limits inclusive of the panic area.
   *
   * returns: SUCCESS   all good.
   *          FAIL      directory in a weird state.
   *          EODATA    panic area is full.  block set to end of panic area
   */
  error_t init_pcb(uint8_t *buf, uint32_t start, uint32_t end) {
    panic_dir_t *dirp;
    error_t rtn;

    pcb.buf       = buf;
    pcb.bptr      = pcb.buf;
    pcb.remaining = SD_BLOCKSIZE;

    /* Initialize pcb with sector addresses */
    pcb.dir       = start;
    pcb.low       = pcb.dir + 1;
    pcb.high      = end;
    pcb.block     = pcb.low;

    rtn = SUCCESS;
    dirp = (panic_dir_t *) buf;
    if (!call SDraw.chk_zero(buf)) {
      if (call Checksum.sum32_aligned((void *) dirp, sizeof(*dirp))
          || dirp->panic_dir_sig != PANIC_DIR_SIG)
        return FAIL;

      if (dirp->panic_block_index >= dirp->panic_block_index_max) {
        pcb.block = index2block(dirp->panic_block_index_max);
        rtn = EODATA;
      } else
        pcb.block = index2block(dirp->panic_block_index);
    }
    /*
     * If the Dir sector is zero, then we simply use the initial values
     * set above, pcb.low.
     */
    pcb.panic_sec = pcb.block;
    pcb.pcb_sig   = PCB_SIG;            /* validate */
    return rtn;
  }


  /*
   * init_panic_dump
   * initialize panic buffer management
   *
   * Typically, someone (SSW) prior to dump will have turned on the
   * SD.  But if not FS.reload_locator_sa() will do it.  Either
   * way we don't need to do a SDsa.reset(), its been done.
   *
   * Don't mess with pcb.in_panic.  Set and/or checked on the
   * entry to Panic.
   */
  void init_panic_dump() {
    uint32_t start, end;
    error_t  rtn;

    if (call FS.reload_locator_sa(panic_buf))
      call OverWatch.strange(0x80);     /* no return */

    start = call FS.area_start(FS_LOC_PANIC);
    end   = call FS.area_end(FS_LOC_PANIC);
    call SDsa.read(start, panic_buf);
    rtn = init_pcb(panic_buf, start, end);
    if (rtn) {
      if (rtn == EODATA) {
        /*
         * if we are good but off the end (ie. full) then reuse
         * the last panic block
         *
         * we have to convert our off the end block into the
         * max index.  back up one index and convert back to a block.
         *
         * this makes sure we have a good starting block number for
         * the panic.  We can NOT simply go to the end of the PANIC
         * area and back up PBLK_SIZE because the formatter might have
         * put some pad sectors on the end when creating the file.
         */
        pcb.block = index2block(block2index(pcb.block) - 1);
        pcb.panic_sec = pcb.block;
      } else {                          /* otherwise, blow up */
        call OverWatch.strange(0x81);
        /* no return */
      }
    }
  }


  void panic_write(uint32_t blk_id, uint8_t *buf) {
    if (pcb.pcb_sig != PCB_SIG
        || blk_id < pcb.dir
        || blk_id  > pcb.high)
      call OverWatch.strange(0x82);
    call SDsa.write(blk_id, buf);
  }


  void update_panic_dir() {
    panic_dir_t *dirp;

    /*
     * need to bump pcb.block to the next panic block if any.
     * pcb.block += PBLK_SIZE
     */
    memset(pcb.buf, 0, SD_BLOCKSIZE);
    dirp                     = (panic_dir_t *) pcb.buf;
    dirp->panic_dir_id[0]    = 'P';
    dirp->panic_dir_id[1]    = 'A';
    dirp->panic_dir_id[2]    = 'N';
    dirp->panic_dir_id[3]    = 'I';
    dirp->panic_dir_sig      = PANIC_DIR_SIG;
    dirp->panic_dir_sector   = pcb.dir;
    dirp->panic_high_sector  = pcb.high;
    dirp->panic_block_index  = block2index(pcb.block + PBLK_SIZE);
    dirp->panic_block_index_max
                             = block2index(pcb.high + 1);
    dirp->panic_block_size   = PBLK_SIZE;
    dirp->panic_dir_checksum = 0;
    dirp->panic_dir_checksum = 0 - call Checksum.sum32_aligned((void *) dirp, sizeof(*dirp));
    panic_write(pcb.dir, pcb.buf);
  }


  void collect_fp(crash_info_t *cip) {
    uint32_t i = 0;

    while (i < 32) {
      cip->fpRegs[i] = 0;
      i++;
    }
  }


  uint32_t byte_checksum_buf(uint8_t *buf, uint32_t len) {
    uint32_t checksum;
    uint8_t *limit;

    checksum = 0;
    limit = &buf[len];
    while (buf < limit)
      checksum += *buf++;
    return checksum;
  }


  uint32_t collect_ram(const panic_region_t *ram_desc, uint32_t delta) {
    uint32_t  len  = ram_desc->len;
    uint8_t  *base = ram_desc->base_addr;
    uint32_t  blk;

    blk = pcb.block + delta;
    while (len > 0) {
      panic_write(blk, base);
      blk++;
      base += SD_BLOCKSIZE;
      len  -= SD_BLOCKSIZE;
    }
    return blk - pcb.block;
  }


  uint32_t checksum_ram(const panic_region_t *ram_desc, uint32_t delta) {
    uint32_t  len  = ram_desc->len;
    uint8_t  *base = ram_desc->base_addr;
    uint32_t  checksum, sec_chk;
    uint32_t  blk;

    blk = pcb.block + delta;
    checksum = 0;
    while (len > 0) {
      call SDsa.read(blk, pcb.buf);
      sec_chk = byte_checksum_buf(pcb.buf, SD_BLOCKSIZE);
      checksum += sec_chk;
      blk++;
      base += SD_BLOCKSIZE;             /* for reference only */
      len  -= SD_BLOCKSIZE;
    }
    pcb.ram_checksum = checksum;
    return checksum;
  }


  /*
   * copy the region pointed at by src into the working buffer at dest
   * update where we left off.
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
  void copy_io_region(uint8_t *src, uint32_t len, uint32_t esize)  {
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
        pcb.io_checksum += byte_checksum_buf(pcb.buf, SD_BLOCKSIZE);
        panic_write(pcb.panic_sec, pcb.buf);
        pcb.panic_sec++;
        dest = pcb.buf;
        d_len = SD_BLOCKSIZE;
      }
      pcb.bptr = dest;
      pcb.remaining = d_len;
    }
  }


  /* uses persistent global in pcb (panic_sec) for where to write */
  void collect_io(const panic_region_t *io_desc, uint32_t delta) {
    cc_region_header_t header;

    pcb.panic_sec = pcb.block + delta;
    pcb.io_checksum = 0;
    while (io_desc->base_addr != PR_EOR) {
      header.start = (uint32_t)io_desc->base_addr;
      header.end = ((uint32_t)io_desc->base_addr + io_desc->len);

      copy_io_region((void *)&header, sizeof(cc_region_header_t), 4);
      copy_io_region(io_desc->base_addr, io_desc->len, io_desc->element_size);
      io_desc++;
    }
    header.start = 0;
    header.end   = 0;
    copy_io_region((void *)&header, sizeof(cc_region_header_t), 4);
    if (pcb.remaining != SD_BLOCKSIZE) {
      call SDraw.zero_fill((uint8_t *)pcb.buf, SD_BLOCKSIZE - pcb.remaining);
      pcb.io_checksum += byte_checksum_buf(pcb.buf, SD_BLOCKSIZE);
      panic_write(pcb.panic_sec, pcb.buf);
      pcb.panic_sec++;
    }
  }


  task void panic_warn_task() {
    dt_event_t    ev;
    dt_event_t   *evp;
    panic_args_t *pap = &_panic_args;

    evp        = &ev;
    evp->len   = sizeof(ev);
    evp->dtype = DT_EVENT;
    evp->ev    = DT_EVENT_PANIC_WARN;
    evp->pcode = pap->pcode;            /* pcode/subsystem */
    evp->w     = pap->where;
    evp->arg0  = pap->a0;
    evp->arg1  = pap->a1;
    evp->arg2  = pap->a2;
    evp->arg3  = pap->a3;
    call Collect.collect((void *) evp, sizeof(ev), NULL, 0);
    atomic _panic_args_warn_busy = FALSE;
  }


  /*
   * Panic.warn: log a Panic Warn event
   *
   * Collect.collect is task level so we can't call it directly but
   * we want to be able to call Panic.warn where ever.
   *
   * So we use the global _panic_args to stash the panic arguments (busy
   * is indicated by _panic_args_warn_busy).  After the panic_warn_task
   * runs and the event has been logged, it will free the block.
   *
   * If a full on Panic occurs while the panic warn is still using the
   * block, well it just doesn't matter.  The Panic will override the
   * warning.  It will also take the system out and then will reboot.
   */
  async command void Panic.warn(uint8_t pcode, uint8_t where,
          parg_t arg0, parg_t arg1, parg_t arg2, parg_t arg3)
      __attribute__ ((noinline)) {

    panic_args_t *pap = &_panic_args;

    atomic {
      if (_panic_args_warn_busy)
        return;
      _panic_args_warn_busy = TRUE;
      pap->pcode = pcode; pap->where = where;
      pap->a0    = arg0;  pap->a1    = arg1;
      pap->a2    = arg2;  pap->a3    = arg3;
    }

    post panic_warn_task();
    nop();                              /* BRK */
  }


#ifdef notdef
  /* verify checksums */
  void verify_panic() {
    uint32_t expected, checksum, sec, sec_chk;
    uint32_t ram_chk, io_chk;
    panic_dir_t *dirp;
    panic_hdr0_t *b0p;                  /* panic zero 0 in panic block  */
    panic_hdr1_t *b1p;                  /* panic zero 1 in panic block  */

    sec = pcb.dir;
    call SDsa.read(sec, pcb.buf);
    dirp = (void *) pcb.buf;
    if (call Checksum.sum32_aligned((void *) dirp, sizeof(*dirp))) {
      /* internal checksum, sums to 0, else blow out */
      call Panic.panic(99, 1, 0, 0, 0, 0);
    }
    sec = pcb.block;
    call SDsa.read(sec, pcb.buf);
    b0p = (void *) pcb.buf;
    expected = b0p->ph0_checksum;
    b0p->ph0_checksum = 0;
    checksum = byte_checksum_buf((void *) b0p, 512);
    if (expected != checksum) {
      /* external checksum */
      call Panic.panic(99, 1, 0, 0, 0, 0);
    }
    sec++;
    call SDsa.read(sec, pcb.buf);
    b1p = (void *) pcb.buf;
    expected = b1p->ph1_checksum;
    b1p->ph1_checksum = 0;
    checksum = byte_checksum_buf((void *) b1p, 512);
    if (expected != checksum) {
      /* external checksum */
      call Panic.panic(99, 1, 0, 0, 0, 0);
    }
    ram_chk = b1p->ram_checksum;
    io_chk  = b1p->io_checksum;
    checksum = 0;
    while (++sec < pcb.block + 128 + 2) {
      call SDsa.read(sec, pcb.buf);
      sec_chk = byte_checksum_buf(pcb.buf, 512);
      checksum += sec_chk;
      nop();
    }
    if (ram_chk != checksum) {
      call Panic.panic(99, 1, 0, 0, 0, 0);
    }
    checksum = 0;
    call SDsa.read(sec++, pcb.buf);
    checksum += byte_checksum_buf(pcb.buf, 512);
    call SDsa.read(sec++, pcb.buf);
    checksum += byte_checksum_buf(pcb.buf, 512);
    if (io_chk != checksum) {
      call Panic.panic(99, 1, 0, 0, 0, 0);
    }
  }
#endif

  /*
   * main portion of panic_main (hem, should we name it something else :-)
   *
   * special entry code has been executed that sets up the _panic_args structure
   * which saves various registers and critical state.
   *
   * This is not reentrant.  On entry, we check for already being in Panic and
   * if so we strange out.  Basically this says the Panic failed.
   *
   * NOTE: interrupt state (primask, faultmask, basepri) is saved on the way
   * in via panic or fault/exception.  Then interrupts are disabled via cpsid.
   */
  void __panic_main()  @C() @spontaneous() {
    panic_args_t        *pap;           /* panic args, working values   */
    exc_old_stack_t     *eos;           /* pointer to failee saved regs */
    panic_old_stack_t   *pos;           /* pointer to failee saved regs */
    panic_crash_stack_t *pcs;           /* pointer to crash stack saved */

    panic_hdr0_t        *b0p;           /* panic zero 0 in panic block  */
    panic_hdr1_t        *b1p;           /* panic zero 1 in panic block  */
    panic_info_t        *pip;           /* panic info in panic_block    */
    panic_additional_t  *addp;          /* additional in panic_block    */
    crash_info_t        *cip;           /* crash_info in panic_block    */
    ow_control_block_t  *owcp;          /* overwatch control block ptr  */

    call OverWatch.incPanicCount();     /* pop appropriate panic ctr    */
    pap = &_panic_args;
    owcp = call OverWatch.getControlBlock();
    owcp->pi_panic_idx = -1;
    owcp->pi_pcode = pap->pcode;
    owcp->pi_where = pap->where;
    owcp->pi_arg0  = pap->a0;
    owcp->pi_arg1  = pap->a1;
    owcp->pi_arg2  = pap->a2;
    owcp->pi_arg3  = pap->a3;

    /*
     * first check to see if we are already in Panic.  There are three
     * cases: (we look at pcb.in_panic)
     *
     *  0 - not in panic.  set to PANIC_IN_PANIC and continue
     *
     *  PANIC_IN_PANIC (0xdeddb00b) - oops.  Strange out.
     *
     *  other value - oops Strange out.  Some one is tweaking the pcb.
     *       Bad.  Sad.  Fake Panic.
     */
    switch (pcb.in_panic) {
      default:
        call OverWatch.strange(0x83);     /* no return */
      case PANIC_IN_PANIC:
        call OverWatch.strange(0x84);     /* no return */
      case 0:
        /* fall through */
    }
    pcb.in_panic = PANIC_IN_PANIC;

    /*
     * initialize the panic control block so we can dump any panic information
     * out to the PANIC AREA on the SD.
     */

    init_panic_dump();

    /*
     * Very first thing write out the i/o sectors.
     * These live after the ram sectors. and is in a fixed position.
     *
     * will fill in pcb.io_checksum on the fly.
     */
    collect_io(&io_regions[0], PBLK_IO);

    /* flush any pending buffers out to the SD. */
    call SysReboot.flush();

    /*
     * signal any modules that a Panic is underway and if possible they
     * should copy any device state into RAM to be copied out.
     */
    signal Panic.hook();

    /*
     * dump RAM out.  then we can do what we want in RAM.
     *
     * after writing the RAM out, reread and calculate the the ram
     * checksum.  We have to do it this way because the underlying ram can
     * change as we are working with the software/hardware used to write
     * out the panic.
     *
     * So write out what we've got to the disk, then read what has actually
     * been written and checksum that.
     *
     * checksum_ram fills in pcb.ram_checksum.
     */

    collect_ram(&ram_region,  PBLK_RAM);
    checksum_ram(&ram_region, PBLK_RAM);

    /* fill in hdr0 */
    memset(pcb.buf, 0, SD_BLOCKSIZE);
    b0p = (panic_hdr0_t *) pcb.buf;

    /* fill in panic info */
    pip = &b0p->panic_info;
    pip->pi_sig     = PANIC_INFO_SIG;
    pip->base_addr  = call OverWatch.getImageBase();
    call Rtc.getTime(&pip->rt);

    pap = &_panic_args;
    pip->pi_pcode = pap->pcode;
    pip->pi_where = pap->where;
    pip->pi_arg0  = pap->a0;
    pip->pi_arg1  = pap->a1;
    pip->pi_arg2  = pap->a2;
    pip->pi_arg3  = pap->a3;

    /* fill in overwatch control block (owcb_info) */
    owcp = call OverWatch.getControlBlock();
    memcpy((void *) (&b0p->owcb_info), (void *) owcp,
           sizeof(*owcp));

    /* fill in image info */
    memcpy((void *) (&b0p->image_info), (void *) (&image_info),
           sizeof(image_info_t));

    /* fill in additional info */
    addp                = &b0p->additional_info;
    addp->ai_sig        = PANIC_ADDITIONS;
    addp->ram_offset    = block2offset(pcb.block + PBLK_RAM);
    addp->ram_size      = PBLK_RAM_SIZE * 512;
    addp->io_offset     = block2offset(pcb.block + PBLK_IO);
    addp->fcrumb_offset = block2offset(pcb.block + PBLK_FCRUMBS);

    b0p->ph0_checksum   = 0;            /* external checksum */
    b0p->ph0_checksum   = byte_checksum_buf((void *) b0p, 512);

    /* flush panic_block_0 (hdr0) buffer */
    panic_write(pcb.block + PBLK_ZERO, pcb.buf);

    /*************************************************************/

    /* build hdr1 */
    memset(pcb.buf, 0, SD_BLOCKSIZE);
    b1p = (panic_hdr1_t *) pcb.buf;
    b1p->ph1_sig = PANIC_HDR1_SIG;
    b1p->core_rev   = CORE_REV;
    b1p->core_minor = CORE_MINOR;
    b1p->ph0_offset = block2offset(pcb.block);
    b1p->ph1_offset = block2offset(pcb.block + 1);
    b1p->ram_checksum = pcb.ram_checksum;
    b1p->io_checksum  = pcb.io_checksum;

    /* fill in crash_info */
    cip = &b1p->crash_info;
    cip->ci_sig = CRASH_INFO_SIG;
    cip->cc_sig = CRASH_CATCHER_SIG;
    cip->flags  = 0;

    pap = &_panic_args;
    if (pap->pcode == PANIC_EXC) {
      eos = (exc_old_stack_t *)(pap->old_sp);
      cip->primask    = eos->primask;
      cip->basepri    = eos->basepri;
      cip->faultmask  = eos->faultmask;
      cip->control    = eos->control;
      cip->bxRegs[0]  = eos->r0;
      cip->bxRegs[1]  = eos->r1;
      cip->bxRegs[2]  = eos->r2;
      cip->bxRegs[3]  = eos->r3;
      cip->bxRegs[12] = eos->r12;
      cip->bxSP       = (uint32_t) pap->old_sp + STACK_ADJUST;
      cip->bxLR       = eos->bxLR;
      cip->bxPC       = eos->bxPC;
      cip->bxPSR      = eos->bxPSR;
    } else {
      pos = (panic_old_stack_t *)(pap->old_sp);
      cip->primask    = pos->primask;
      cip->basepri    = pos->basepri;
      cip->faultmask  = pos->faultmask;
      cip->control    = pos->control;
      cip->bxRegs[0]  = pos->pcode;
      cip->bxRegs[1]  = pos->where;
      cip->bxRegs[2]  = pos->a0;
      cip->bxRegs[3]  = pos->a1;
      cip->bxRegs[12] = pos->r12;
      cip->bxSP       = (uint32_t) pap->old_sp + STACK_ADJUST;
      cip->bxLR       = pos->bxLR;
      cip->bxPC       = pos->bxPC;
      cip->bxPSR      = pos->bxPSR;
    }
    pcs = (panic_crash_stack_t *) (pap->cs_regs_sp);
    cip->axPSR        = pcs->axPSR;
    cip->PSP          = pcs->PSP;
    cip->MSP          = pcs->MSP;
    cip->bxRegs[4]    = pcs->r4;
    cip->bxRegs[5]    = pcs->r5;
    cip->bxRegs[6]    = pcs->r6;
    cip->bxRegs[7]    = pcs->r7;
    cip->bxRegs[8]    = pcs->r8;
    cip->bxRegs[9]    = pcs->r9;
    cip->bxRegs[10]   = pcs->r10;
    cip->bxRegs[11]   = pcs->r11;
    cip->axLR         = pcs->axLR;

    /* copy fpRegs and fpscr to buffer */
    collect_fp(cip);
    cip->fpscr = 0;

    /* fill in ram_header */
    b1p->ram_header.start = (uint32_t) (ram_region.base_addr);
    b1p->ram_header.end   = (uint32_t) (ram_region.base_addr + ram_region.len);

    b1p->ph1_checksum = 0;
    b1p->ph1_checksum = byte_checksum_buf((void *) b1p, 512);

    /* write out panic hdr 1 sector */
    panic_write(pcb.block + PBLK_ZERO + 1, pcb.buf);

    update_panic_dir();
    call SDsa.off();

    /* put the index of the panic just written into the OW control block */
    owcp = call OverWatch.getControlBlock();
    owcp->pi_panic_idx = block2index(pcb.block);

//    ROM_DEBUG_BREAK(0xf0);

#ifdef PANIC_GATE
    while (g_panic_gate != 0xdeadbeaf) {
      nop();
    }
    g_panic_gate = 0;
#endif
    call OverWatch.fail(ORR_PANIC);
    /* shouldn't return */
    call OverWatch.strange(0x85);       /* no return */
  }


  void __panic_panic_entry(uint32_t *old_sp, uint32_t *crash_sp)
      @C() @spontaneous() {

    panic_args_t       *pap;            /* panic args, stash working */
    panic_old_stack_t  *pos;

    /*
     * The crash_stack is immediately below the main stack.  If the main
     * stack has overflowed the registers we have saved on the crash_stack
     * will have wiped any values we thought we were saving on the old_stack
     * Detect this condition and leave the panic_args as zero.  We set
     * pcode to -1 to indicate something really bogus has occurred.
     */

    pap = &_panic_args;

    pap->old_sp       = old_sp;
    pap->cs_regs_sp   = crash_sp;
    pos               = (panic_old_stack_t *) old_sp;

    if (old_sp < &__crash_stack_top__)
      pap->pcode      = -1;             /* say really bogus. */
    else {
      pap->pcode     = pos->pcode;
      pap->where     = pos->where;
      pap->a0        = pos->a0;
      pap->a1        = pos->a1;
      pap->a2        = pos->a2;
      pap->a3        = pos->a3;
    }
    __panic_main();
  }


  /*
   * Panic.panic: something really bad happened.
   * use __panic_entry to save what is required and switch to
   * a new stack.
   *
   * __panic_entry is platform dependent assembly code located in
   * tos/chips/msp432/PanicHelperP.nc
   *
   * return from the assembly language is via __panic_panic_entry
   *
   * By convention, a Panic.panic with pcode of 0 says a null
   * pointer test failed.
   */

  extern void __panic_entry() @C();

  async command void Panic.panic(uint8_t pcode, uint8_t where,
          parg_t arg0, parg_t arg1, parg_t arg2, parg_t arg3)
      __attribute__ ((naked, noinline)) {

    /*
     * we just jump directly to __panic_entry.  It will handle dealing
     * with the parameters and saving state.
     *
     * optimized code can use a C call but unoptimized replaces this
     * with a bl which messes with the LR register.
     *
     * The NOP below is where we put a breakpoint to catch panics.  This
     * allows us to step up the stack to the failure.  Later we will have
     * switched to a different stack which then makes backtraces problematic.
     */
    nop();                              /* BRK */
#ifdef PANIC_GATE
    while (g_panic_gate != 0xdeadbeaf) {
      nop();
    }
    g_panic_gate = 0;
#endif
    __asm__ volatile ("b __panic_entry \n");

    /* returns via __panic_panic_entry */
  }


  void __panic_exception_entry(uint32_t *old_sp, uint32_t *crash_sp)
      @C() @spontaneous() {

    panic_args_t        *pap;           /* panic args ptr    (pap) */
    panic_crash_stack_t *pcs;           /* panic crash stack (pcs) */

    /*
     * The crash_stack is immediately below the main stack.  If the main
     * stack has overflowed the registers we have saved on the crash_stack
     * will have wiped any values we thought we were saving on the old_stack
     * Detect this condition and leave the panic_args as zero.  We set
     * pcode to -1 to indicate something really bogus has occurred.
     */
    pap = &_panic_args;
    pap->old_sp       = old_sp;
    pap->cs_regs_sp   = crash_sp;
    pcs = (panic_crash_stack_t *) crash_sp;

    if (old_sp < &__crash_stack_top__)
      pap->pcode      = -1;             /* say really bogus, OUCH. */
    else {
      pap->pcode     = PANIC_EXC;
      pap->where     = pcs->axPSR & 0x1ff;
      pap->a0        = 0;
      pap->a1        = 0;
      pap->a2        = 0;
      pap->a3        = 0;
    }
    __panic_main();
  }


  /* returns directory sector absolute blk_id */
  command uint32_t PanicManager.getPanicBase() {
    if (pcb.pcb_sig != PCB_SIG)
      return 0;
    return pcb.dir;
  }


  /* return upper abs blk id of panic area, inclusive */
  command uint32_t PanicManager.getPanicLimit() {
    if (pcb.pcb_sig != PCB_SIG)
      return 0;
    return pcb.high;
  }


  /* return current known panic index.  number of panics written */
  command uint32_t PanicManager.getPanicIndex() {
    if (pcb.pcb_sig != PCB_SIG)
      return 0;
    return block2index(pcb.block);
  }


  /* return largest index, indicates full */
  command uint32_t PanicManager.getMaxPanicIndex() {
    if (pcb.pcb_sig != PCB_SIG)
      return 0;
    return block2index(pcb.high + 1);
  }


  /* return size of each panic block in sectors */
  command uint32_t PanicManager.getPanicSize() {
    return PBLK_SIZE;
  }


  /* return absolute sector number for the start of panic <N> */
  command uint32_t PanicManager.panicIndex2Sector(uint32_t idx) {
    if (pcb.pcb_sig != PCB_SIG)
      return 0;
    return index2block(idx);
  }


  /*
   * populate panic directory so we can look at it.  task level
   *
   * caller must catch errors.  And handler errors from the
   * populate_dir_done signal.
   */
  command error_t PanicManager.populate() {
    pcb.pcb_sig = 0;
    return call SDResource.request();
  }


  event void SDResource.granted() {
    error_t err;
    uint32_t start;

    start = call FS.area_start(FS_LOC_PANIC);
    if ((err = call SDread.read(start, panic_buf))) {
      call SDResource.release();
      signal PanicManager.populateDone(err);
    }
  }


  event void SDread.readDone(uint32_t blk_id, uint8_t *read_buf, error_t err) {
    uint32_t start, end;

    if (err) {
      call SDResource.release();
      signal PanicManager.populateDone(err);
      return;
    }
    start = call FS.area_start(FS_LOC_PANIC);
    end   = call FS.area_end(FS_LOC_PANIC);
    if (start != blk_id || read_buf != panic_buf) {
      /* weirdness */
      call SDResource.release();
      signal PanicManager.populateDone(FAIL);
      return;
    }
    call SDResource.release();
    err = init_pcb(panic_buf, start, end);
    signal PanicManager.populateDone(err);
  }


  default event void PanicManager.populateDone(error_t err) { }

        event void FS.eraseDone(uint8_t which) { }
        event void Collect.collectBooted()     { }
        event void Collect.resyncDone(error_t err, uint32_t offset) { }
  async event void SysReboot.shutdown_flush()  { }

  default async event void Panic.hook()        { }
}
