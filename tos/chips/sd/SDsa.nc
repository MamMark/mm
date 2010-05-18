/*
 * Copyright (c) 2010, Eric B. Decker, Carl W. Davis
 * All rights reserved.
 *
 * @author Eric B. Decker
 * @author Carl W. Davis
 */

interface SDsa {
  command error_t reset();

  command error_t read(uint32_t blk_id, void *buf);

  command error_t write(uint32_t blk, void *buf);
}
