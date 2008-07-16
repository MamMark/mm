/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

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
}

implementation {

  void debug_break()  __attribute__ ((noinline)) {
    MAYBE_SAVE_SR_AND_DINT;
    nop();
    call Panic.panic(0,0,0,0,0,0);
  }

  async command void Panic.warn(uint8_t pcode, uint8_t where, uint16_t arg0, uint16_t arg1, uint16_t arg2, uint16_t arg3) {
    call Panic.panic(pcode, where, arg0, arg1, arg2, arg3);
  }

  async command void Panic.panic(uint8_t pcode, uint8_t where, uint16_t arg0, uint16_t arg1, uint16_t arg2, uint16_t arg3) {
    _p = pcode; _w = where; _a0 = arg0; _a1 = arg1; _a2 = arg2; _a3 = arg3;
    MAYBE_SAVE_SR_AND_DINT;
    if (pcode == 0)
      return;
    debug_break();
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
