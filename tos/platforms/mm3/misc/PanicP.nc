/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#include "panic.h"
#include "sd_blocks.h"

norace uint16_t save_sr;
norace bool save_sr_free;
norace uint8_t _p, _w;
norace uint16_t _a0, _a1, _a2, _a3;

#define MAYBE_SAVE_SR_AND_DINT	do {	\
    if (save_sr_free) {			\
      save_sr = READ_SR;		\
      save_sr_free = FALSE;		\
    }					\
    dint();				\
} while (0);


module PanicP {
  provides {
    interface Panic;
    interface Init;
  }
  uses {
    interface Collect;
    interface LocalTime<TMilli>;
  }
}

implementation {
  norace dt_panic_nt p_blk;
  norace bool p_blk_busy;

  task void panic_task() {
    call Collect.collect((uint8_t *) &p_blk, sizeof(dt_panic_nt));
    p_blk_busy = FALSE;
  }

  void debug_break()  __attribute__ ((noinline)) {
    MAYBE_SAVE_SR_AND_DINT;
    nop();
  }

  async command void Panic.warn(uint8_t pcode, uint8_t where, uint16_t arg0, uint16_t arg1, uint16_t arg2, uint16_t arg3) {
    pcode |= PANIC_WARN_FLAG;
    call Panic.panic(pcode, where, arg0, arg1, arg2, arg3);
  }

  async command void Panic.panic(uint8_t pcode, uint8_t where, uint16_t arg0, uint16_t arg1, uint16_t arg2, uint16_t arg3) {

    _p = pcode; _w = where; _a0 = arg0; _a1 = arg1; _a2 = arg2; _a3 = arg3;
    MAYBE_SAVE_SR_AND_DINT;
    nop();

    if (pcode == PANIC_SD || pcode == PANIC_SS)
      return;

    if (p_blk_busy)
      return;
    p_blk_busy = TRUE;
    p_blk.len = sizeof(dt_panic_nt);
    p_blk.dtype = DT_PANIC;
    p_blk.stamp_mis = call LocalTime.get();
    p_blk.pcode = pcode;
    p_blk.where = where;
    p_blk.arg0 = arg0;
    p_blk.arg1 = arg1;
    p_blk.arg2 = arg2;
    p_blk.arg3 = arg3;
    post panic_task();
  }

  async command void Panic.reboot(uint8_t pcode, uint8_t where, uint16_t arg0, uint16_t arg1, uint16_t arg2, uint16_t arg3) {
    call Panic.panic(pcode, where, arg0, arg1, arg2, arg3);
  }

  async command void Panic.brk() {
    debug_break();
  }
    
  command error_t Init.init() {
    save_sr_free = TRUE;
    save_sr = 0xffff;
    return SUCCESS;
  }
}
