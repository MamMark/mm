/*
 * Copyright (c) 2012, Eric B. Decker
 * All rights reserved.
 *
 * This module provides a simple Panic interface.   It currently
 * does nothing but provides a place where Panics can be seen (like
 * from a debugger).
 */

#include "panic.h"
#include "typed_data.h"

uint16_t save_sr;
bool save_sr_free;
norace uint8_t _p, _w;
norace uint16_t _a0, _a1, _a2, _a3, _arg;

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
}

implementation {

  void debug_break(uint16_t arg)  __attribute__ ((noinline)) {
    _arg = arg;
    nop();
  }


  async command void Panic.warn(uint8_t pcode, uint8_t where, uint16_t arg0, uint16_t arg1,
				uint16_t arg2, uint16_t arg3) {

    pcode |= PANIC_WARN_FLAG;

    _p = pcode; _w = where;
    _a0 = arg0; _a1 = arg1;
    _a2 = arg2; _a3 = arg3;

    MAYBE_SAVE_SR_AND_DINT;
    debug_break(0);
  }


  /*
   * Panic.panic: something really bad happened.
   * Simple version.   Do nothing allow debug break.
   */

  async command void Panic.panic(uint8_t pcode, uint8_t where, uint16_t arg0, uint16_t arg1,
				 uint16_t arg2, uint16_t arg3) {
    _p = pcode; _w = where;
    _a0 = arg0; _a1 = arg1;
    _a2 = arg2; _a3 = arg3;
    debug_break(1);
  }


  command error_t Init.init() {
    save_sr_free = TRUE;
    save_sr = 0xffff;
    return SUCCESS;
  }
}
