/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#include "panic.h"
#include "typed_data.h"

norace uint16_t save_sr;
norace bool save_sr_free;
norace uint8_t _p, _w;
norace uint16_t _a0, _a1, _a2, _a3, _arg;
norace uint32_t last_panic;

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

module PanicP {
  provides {
    interface Panic;
    interface Init;
  }
  uses {
    interface Collect;
    interface LocalTime<TMilli>;
    interface SDsa;
  }
}

implementation {
  norace struct p_blk_struct {
    bool busy;
    dt_panic_nt blk;
  } p_blk[P_BLK_SIZE];

  norace uint16_t missed_panics;

  task void panic_task() {
    int i;

    atomic {
      for (i = 0; i < P_BLK_SIZE; i++) {
	if (p_blk[i].busy) {
	  call Collect.collect((uint8_t *) &p_blk[i].blk, sizeof(dt_panic_nt));
	  p_blk[i].busy = FALSE;
	}
      }
    }
  }

  void debug_break(uint16_t arg)  __attribute__ ((noinline)) {
//    MAYBE_SAVE_SR_AND_DINT;
    _arg = arg;
    nop();
  }

  async command void Panic.warn(uint8_t pcode, uint8_t where, uint16_t arg0, uint16_t arg1, uint16_t arg2, uint16_t arg3) {
    pcode |= PANIC_WARN_FLAG;
    call Panic.panic(pcode, where, arg0, arg1, arg2, arg3);
  }

  async command void Panic.panic(uint8_t pcode, uint8_t where, uint16_t arg0, uint16_t arg1, uint16_t arg2, uint16_t arg3) {
    struct p_blk_struct *p;
    uint8_t temp;

    _p = pcode; _w = where; _a0 = arg0; _a1 = arg1; _a2 = arg2; _a3 = arg3;
    MAYBE_SAVE_SR_AND_DINT;
    last_panic = call LocalTime.get();
    nop();

    if (call SDsa.inSA()) {
      while (1)
	nop();
    }

    temp = pcode & ~PANIC_WARN_FLAG;
    if (temp == PANIC_MS || temp == PANIC_SS)
      return;

    if (!p_blk[0].busy)
      p = &p_blk[0];
    else if (!p_blk[1].busy)
      p = &p_blk[1];
    else {
      missed_panics++;
      return;
    }

    p->busy = TRUE;
    p->blk.len = sizeof(dt_panic_nt);
    p->blk.dtype = DT_PANIC;
    p->blk.stamp_mis = call LocalTime.get();
    p->blk.pcode = pcode;
    p->blk.where = where;
    p->blk.arg0 = arg0;
    p->blk.arg1 = arg1;
    p->blk.arg2 = arg2;
    p->blk.arg3 = arg3;
    post panic_task();
  }

  async command void Panic.reboot(uint8_t pcode, uint8_t where, uint16_t arg0, uint16_t arg1, uint16_t arg2, uint16_t arg3) {
    call Panic.panic(pcode, where, arg0, arg1, arg2, arg3);
  }

  async command void Panic.brk(uint16_t arg) {
    debug_break(arg);
  }
    
  command error_t Init.init() {
    save_sr_free = TRUE;
    save_sr = 0xffff;
    return SUCCESS;
  }
}
