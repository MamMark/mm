/**
 * Copyright (c) 2008, Eric Decker
 * All rights reserved.
 */

/**
 * @author Eric Decker
 */

#include "stream_storage.h"

interface StreamStorageRead {

  /**
   *
   *
   */
  command error_t read_block(uint32_t blk, uint8_t *buf);
  event void read_block_done(uint32_t blk, uint8_t *buf, error_t err);
}
