/**
 * Copyright (c) 2017, Eric B. Decker
 * Copyright (c) 2010, Eric Decker, Carl Davis
 * All rights reserved.
 */

/**
 * @author Eric B. Decker
 * @author Carl Davis
 */

#include <fs_loc.h>

interface FileSystem {
  /*
   * return area start and end
   */
  async command uint32_t area_start(uint8_t which);
  async command uint32_t area_end(uint8_t which);

  /* erase a region, split phase */
  command error_t  erase(uint8_t which);
  event   void     eraseDone(uint8_t which);
}
