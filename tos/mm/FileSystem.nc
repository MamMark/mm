/**
 * Copyright (c) 2010, Eric Decker, Carl Davis
 * All rights reserved.
 */

/**
 * @author Eric Decker
 * @author Carl Davis
 */

#include "file_system.h"

interface FileSystem {
  command uint32_t area_start(uint8_t which);
  command uint32_t area_end(uint8_t which);
}
