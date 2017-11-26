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
#include <overwatch.h>

#ifdef PANIC_GATE
norace volatile uint32_t g_panic_gate;
#endif

#ifdef   PANIC_WIGGLE
#ifndef  WIGGLE_EXC
#warning WIGGLE_EXC not defined, using default nothingness
#define  WIGGLE_EXC do{} while (0)
#define  WIGGLE_DELAY 1
#endif
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
  uint32_t block;              /* where the block starts */
  uint32_t panic_sec;          /* current sector being written */

  /* panic control, only active after a Panic happens */
  uint32_t dir;                /* directory sector */
  uint32_t low;                /* low  limit for blocks */
  uint32_t high;               /* high limit for blocks */
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

module PanicP {
  provides interface Panic;
  uses {
    interface SSWrite  as SSW;
    interface Platform;
    interface FileSystem as FS;
    interface OverWatch;
    interface SDsa;                     /* standalone */
    interface SDraw;                    /* other SD aux */
    interface Checksum;
    interface SysReboot;
    interface LocalTime<TMilli>;
    interface Collect;
  }
}

implementation {
#ifdef PANIC_WIGGLE
  /*
   * deprecated.  Only useful on the dev6a.
   */
  void debug_break(parg_t arg)  __attribute__ ((noinline)) {
    uint32_t t0;
    uint32_t i;

    WIGGLE_EXC; WIGGLE_EXC; WIGGLE_EXC; WIGGLE_EXC;     /* 4 */
    t0 = call Platform.usecsRaw();
    while ((call Platform.usecsRaw() - t0) < WIGGLE_DELAY) ;

    for (i = 0; i < _panic_args.pcode; i++)
      WIGGLE_EXC;
    t0 = call Platform.usecsRaw();
    while ((call Platform.usecsRaw() - t0) < WIGGLE_DELAY) ;

    for (i = 0; i < _panic_args.where; i++)
      WIGGLE_EXC;
    t0 = call Platform.usecsRaw();
    while ((call Platform.usecsRaw() - t0) < WIGGLE_DELAY) ;
    WIGGLE_EXC; WIGGLE_EXC; WIGGLE_EXC; WIGGLE_EXC;     /* 4 */

    nop();                              /* the other place */
    ROM_DEBUG_BREAK(0xf0);
  }
#else
  void debug_break(parg_t arg)  __attribute__ ((noinline)) {
    nop();                              /* BRK */
    ROM_DEBUG_BREAK(0xf0);
  }
#endif


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
    panic_dir_t *dirp;

    pcb.pcb_sig   = PCB_SIG;
    pcb.buf       = call SSW.get_temp_buf();
    pcb.bptr      = pcb.buf;
    pcb.remaining = SD_BLOCKSIZE;

    if (call FS.reload_locator_sa(pcb.buf))
      call OverWatch.strange(0x80);     /* no return */

    /* Initialize pcb with sector addresses */
    pcb.dir       = call FS.area_start(FS_LOC_PANIC);
    pcb.low       = pcb.dir + 1;
    pcb.high      = call FS.area_end(FS_LOC_PANIC);
    pcb.block     = pcb.low;
    pcb.panic_sec = pcb.block;

    call SDsa.read(pcb.dir, pcb.buf);
    dirp = (panic_dir_t *) pcb.buf;

    if (!call SDraw.chk_zero(pcb.buf)) {
      if (call Checksum.sum32_aligned((void *) dirp, sizeof(*dirp))
          || dirp->panic_dir_sig != PANIC_DIR_SIG)
        call OverWatch.strange(0x81);

      /*
       * if the dir sector has something in it and it passes the validity
       * checks then use the sector value in it as the starting point for
       * the next panic block.
       */
      pcb.block = dirp->panic_block_sector;
      pcb.panic_sec = pcb.block;
    }

    /*
     * If the Dir sector is zero, then we simply use the initial values
     * set above, pcb.low.
     */
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
    dirp                     = (panic_dir_t *) pcb.buf;
    dirp->panic_dir_sig      = PANIC_DIR_SIG;
    dirp->panic_dir          = pcb.dir;
    dirp->panic_high         = pcb.high;
    dirp->panic_block_sector = pcb.block + PBLK_SIZE;
    dirp->panic_block_size   = PBLK_SIZE;
    dirp->panic_dir_checksum = 0;
    dirp->panic_dir_checksum = 0 - call Checksum.sum32_aligned((void *) dirp, sizeof(*dirp));

    panic_write(pcb.dir, pcb.buf);
    call SDsa.off();
  }


  void collect_fp(crash_info_t *cip) {
    uint32_t i = 0;

    while (i < 32) {
      cip->fpRegs[i] = 0;
      i++;
    }
  }


  uint32_t collect_ram(const panic_region_t *ram_desc, uint32_t start_sec) {
    uint32_t len = ram_desc->len;
    uint8_t *base = ram_desc->base_addr;

    while (len > 0) {
      panic_write(start_sec, base);
      start_sec++;
      base += 512;
      len  -= 512;
    }
    return start_sec;
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


  /* uses persistent global in pcb (panic_sec) for where to write */
  void collect_io(const panic_region_t *io_desc) {
    cc_region_header_t header;

    while (io_desc->base_addr != PR_EOR) {
      header.start = (uint32_t)io_desc->base_addr;
      header.end = ((uint32_t)io_desc->base_addr + io_desc->len);

      copy_region((void *)&header, sizeof(cc_region_header_t), 4);
      copy_region(io_desc->base_addr, io_desc->len, io_desc->element_size);
      io_desc++;
    }
    if (pcb.remaining != SD_BLOCKSIZE) {
      call SDraw.zero_fill((uint8_t *)pcb.buf, SD_BLOCKSIZE - pcb.remaining);
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
    evp->ss    = pap->pcode;            /* subsystem */
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


  /*
   * main portion of panic_main (hem, should we name it something else :-)
   *
   * special entry code has been executed that sets up the _panic_args structure
   * which saves various registers and critical state.
   *
   * This is not reentrant.  On entry, we check for already being in Panic and
   * if so we strange out.  Basically this says the Panic failed.
   */
  void __panic_main()  @C() @spontaneous() {
    panic_args_t        *pap;           /* panic args, working values   */
    exc_old_stack_t     *eos;           /* pointer to failee saved regs */
    panic_old_stack_t   *pos;           /* pointer to failee saved regs */
    panic_crash_stack_t *pcs;           /* pointer to crash stack saved */

    panic_block_0_t     *b0p;           /* panic block 0 in panic block */
    panic_info_t        *pip;           /* panic info in panic_block    */
    panic_additional_t  *addp;          /* additional in panic_block    */
    crash_info_t        *cip;           /* crash_info in panic_block    */
    ow_control_block_t  *owcp;          /* overwatch control block ptr  */

    /*
     * first check to see if we are already in Panic.  There are three
     * cases: (we look at pcb.in_panic)
     *
     *  0 - not in panic.  set to PANIC_IN_PANIC and continue
     *
     *  PANIC_IN_PANIC (0xdeddb00b) - oops.  Strange out.
     *
     *  other value - oops Strange out.  Some one is tweaking the pcb.
     *       Bad.  Sad.
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

    debug_break(0);

    /*
     * initialize the panic control block so we can dump any panic information
     * out to the PANIC AREA on the SD.
     */

    init_panic_dump();

    b0p = (panic_block_0_t *) pcb.buf;

    /* fill in crash_info */
    cip = &b0p->crash_info;
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

    nop();                              /* BRK */

    /* copy fpRegs and fpscr to buffer */
    collect_fp(cip);
    cip->fpscr = 0;

    /* fill in panic info */
    owcp = call OverWatch.getControlBlock();
    pip = &b0p->panic_info;
    pip->sig = PANIC_INFO_SIG;
    pip->boot_count = owcp->reboot_count;
    pip->systime    = call LocalTime.get();
    pip->subsys = pap->pcode;
    pip->where  = pap->where;
    pip->pad    = 0;
    pip->arg[0] = pap->a0;
    pip->arg[1] = pap->a1;
    pip->arg[2] = pap->a2;
    pip->arg[3] = pap->a3;

    /* fill in additional info */
    addp                = &b0p->additional_info;
    addp->sig           = PANIC_ADDITIONS;
    addp->ram_sector    = pcb.block + PBLK_RAM;
    addp->ram_size      = PBLK_RAM_SIZE * 512;
    addp->io_sector     = pcb.block + PBLK_IO;
    addp->fcrumb_sector = pcb.block + PBLK_FCRUMBS;

    /* fill in image info */
    memcpy((void *) (&b0p->image_info), (void *) (&image_info), sizeof(image_info_t));

    /* fill in ram_header */
    b0p->ram_header.start = (uint32_t) (ram_region.base_addr);
    b0p->ram_header.end   = (uint32_t) (ram_region.base_addr + ram_region.len);

    /* flush panic_block_0 buffer */
    panic_write(pcb.panic_sec, pcb.buf);
    pcb.panic_sec++;

    /*
     * First flush any pending buffers out to the SD.
     *
     * Note: If the PANIC is from the SSW or SD subsystem don't flush the buffers.
     */
    if (pap->pcode != PANIC_SD && pap->pcode != PANIC_SS)
      call SysReboot.flush();

    /*
     * signal any modules that a Panic is underway and if possible they should copy any
     * device state into RAM to be copied out.
     */
    signal Panic.hook();

    /* first dump RAM out.  then we can do what we want in RAM */
    collect_ram(&ram_region, pcb.block + PBLK_RAM);

    pcb.panic_sec = pcb.block + PBLK_IO;
    collect_io(&io_regions[0]);
    update_panic_dir();
    ROM_DEBUG_BREAK(0xf0);

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
   * linkage to __panic_panic_entry
   * switch to new stack and preserve state
   *
   * r0 (new_stack): is the address we want for the crash stack
   *    this is a workaround to set the stack to a fixed location.
   *
   * we want to make the crash_stack hold the same stuff as what an
   * panic_exec_entry does.  Namely:
   *
   *  top of crash_stack:
   *    axLR    <- we need to fake this.  See below.
   *    r11
   *    r10
   *    r9
   *    r8
   *    r7
   *    r6
   *    r5
   *    r4
   *    msp
   *    psp
   *    axPSR   <- from current xPSR.
   *
   * the axLR is set to indicate 8 words, handler, MSP.  0x00000011
   * we do NOT pretend to be an EXC_RTN that would be ugly.
   */

  void __launch_panic_panic(void *new_stack)
      __attribute__((naked, noinline)) @C() @spontaneous() {

    __asm__ volatile (
      "mov  r1, sp       \n"            /* save old_stack           */
      "mov  sp, r0       \n"            /* switch to new stack      */
      "mov  r0, r1       \n"            /* arg0 for panic_entry     */
      "mrs  r1, XPSR     \n"            /* save the axPSR           */
      "mrs  r2, PSP      \n"
      "mrs  r3, MSP      \n"
      "mov  lr, %[flr]   \n"
      "push {r1-r11, lr} \n"            /* save remaining registers */
      "mov  r1, sp       \n"            /* cur crash_stack          */
      "b    __panic_panic_entry \n"
      : : [flr]"I"(0x11) : "cc", "memory", "sp");
  }


  /*
   * Panic.panic: something really bad happened.
   * switch to crash_stack
   *
   * We push more stuff on the stack to first get scratch registers we can
   * use to save state.  Also we do it so the old_stack looks like what
   * and exception lays down.  This makes the extraction code the same.
   *
   * The panic_panic extraction code has to know where all the Panic
   * parameters live.  We also have to do a dance to grab the xPSR.
   *
   * We also nab the special registers, PRIMASK, BASEPRI, FAULTMASK, and
   * CONTROL.
   *
   * we then use __launch_panic_panic with the address of the stack pointer.
   * This is to work around problems with setting the SP directly.
   * (compiler/assembler ate my code).
   *
   * Hopefully, this preserves the stack linkage and gdb doesn't get lost.
   * This sometimes works.  And other times doesn't depends on the
   * optimization and how much gdb knows from the ELF file.
   */
  async command void Panic.panic(uint8_t pcode, uint8_t where,
          parg_t arg0, parg_t arg1, parg_t arg2, parg_t arg3)
      __attribute__ ((naked, noinline)) {

    __asm__ volatile (
      /*
       * we want the following which will eventually look like an
       * exception frame.
       *
       * offset from SP (after we save)
       *  28    bxPSR           need space for this
       *  24    bxPC            need space for this
       *  20    bxLR
       *  16    bxR12
       *  12    bxR3
       *   8    bxR2
       *   4    bxR1
       *   0    bxR0
       *
       * space for the xPSR and save r0-r3, r12, lr, pc which
       * is what an exception frame looks like.
       */
      "push  {r0-r1}          \n"       /* need space for xPSR and PC */
      "push  {r0-r3, r12, lr} \n"       /* first save and get scratch */

      "mrs   r0, primask      \n"       /* get int enable             */
      "cpsid i                \n"       /* disable normal interrupts  */

      "mov   lr, pc           \n"       /* capture a reasonable PC    */
      "sub   lr, lr, #16      \n"       /* adjust to pnt at start     */
      "mrs   r1, XPSR         \n"       /* nab XPSR and put it where  */
      "str   r1, [SP, #28]    \n"       /* it belongs                 */
      "str   lr, [SP, #24]    \n"       /* stash PC where it belongs  */

      "mrs   r1, basepri      \n"       /* get basepri                */
      "mrs   r2, faultmask    \n"       /* fault mask                 */
      "mrs   r3, control      \n"       /* and finally the CONTROL    */
      "push  {r0-r3}          \n"       /* and save on old stack      */
      : : : "cc", "memory");
    __launch_panic_panic(&__crash_stack_top__);
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


  /* debug code in startup.c (platform) */
  extern void handler_debug(uint32_t exception) @C();

  void __launch_panic_exception(void *new_stack, uint32_t cur_lr)
      __attribute__((naked, noinline)) @C() @spontaneous() {

    __asm__ volatile (
      "mov  lr, r1       \n"            /* restore axLR             */
      "mov  r1, sp       \n"            /* save old_stack           */
      "mov  sp, r0       \n"            /* switch to new stack      */
      "mov  r0, r1       \n"            /* arg0 for panic_entry     */
      "mrs  r1, XPSR     \n"            /* save the axPSR           */
      "mrs  r2, PSP      \n"
      "mrs  r3, MSP      \n"
      "push {r1-r11, lr} \n"            /* save remaining registers */
      "mov  r1, sp       \n"            /* cur crash_stack          */
      : : : "cc", "memory", "sp");

    __asm__ volatile (
      "push {r0-r3, lr}     \n"         /* save for call, debug     */
      "mrs  r0, XPSR        \n"         /* get the exception again  */
      "ubfx r0, r0, #0, #9  \n"         /* extract exception        */
      "bl   handler_debug   \n"         /* debug                    */
      "pop  {r0-r3, lr}     \n"
      : : : "cc", "memory");

    __asm__ volatile (
      "b    __panic_exception_entry \n"
      : : : "cc", "memory");
  }


  event void FS.eraseDone(uint8_t which) { }

  async event void SysReboot.shutdown_flush() { }

  default async event void Panic.hook() { }
}
