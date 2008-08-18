/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

interface SenseVal {
  event void valAvail(uint16_t val, uint32_t stamp);
}
