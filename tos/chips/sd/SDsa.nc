/*
 * Copyright (c) 2010, Eric B. Decker, Carl W. Davis
 * All rights reserved.
 *
 * @author Eric B. Decker
 * @author Carl W. Davis
 */

interface SDsa {
  async command bool inSA();
  async command void reset();
  async command void off();
  async command void read(uint32_t blk_id, uint8_t *buf);
  async command void write(uint32_t blk, uint8_t *buf);
}
