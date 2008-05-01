/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

interface Panic {
  async command void  warn(uint8_t pcode, uint8_t where, uint16_t arg0, uint16_t arg1, uint16_t arg2, uint16_t arg3);
  async command void panic(uint8_t pcode, uint8_t where, uint16_t arg0, uint16_t arg1, uint16_t arg2, uint16_t arg3);
  async command void brk();
}
