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
  command uint32_t area_start(uint8_t which);
  command uint32_t area_end(uint8_t which);
}
