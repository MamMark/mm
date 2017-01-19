/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

interface GPSMsg {
  command void reset();

  async command void byteAvail(uint8_t byte);

  async event void msgBoundary();
  async command bool atMsgBoundary();
}
