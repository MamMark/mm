/*
 * Copyright (c) 2012, 2016, Eric B. Decker
 * All rights reserved.
 *
 * GPSMsgS: GPSMsg interface, synchronous version.
 */

interface GPSMsgS {
  command void     reset();
  command uint16_t eavesIndex();
  command void     eavesDrop(uint8_t byte);

  command bool     byteAvail(uint8_t byte);
  command uint16_t processBuffer(uint8_t *buf, uint16_t len);

  command bool     bufferAvail();
  command bool     atMsgBoundary();
  event   void     resume();
  event   bool     packetAvail(uint8_t *msg);
}
