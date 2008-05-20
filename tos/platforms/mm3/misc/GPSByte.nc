/**
 * Copyright (c) 2008, Eric Decker
 * All rights reserved.
 */

/**
 * @author Eric Decker
 */

interface GPSByte {
  /**
   * signal that a byte is available.  This occurs from interrupt context.
   */  

  async event void byte_avail(uint8_t byte);
}
