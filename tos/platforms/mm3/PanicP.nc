/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

module PanicP {
  provides {
    interface Panic;
    interface Init;
  }
}

implementation {

  void debug_break()  __attribute__ ((noinline)) {
    nop();
    call Panic.panic(0,0,0,0,0,0);
  }

  command void Panic.warn(uint8_t pcode, uint8_t where, uint16_t arg0, uint16_t arg1, uint16_t arg2, uint16_t arg3) {
    debug_break();
  }

  command void Panic.panic(uint8_t pcode, uint8_t where, uint16_t arg0, uint16_t arg1, uint16_t arg2, uint16_t arg3) {
    if (pcode == 0)
      return;
    debug_break();
  }

  command void Panic.brk() {
    debug_break();
  }
    
  command error_t Init.init() {
    return SUCCESS;
  }
}
