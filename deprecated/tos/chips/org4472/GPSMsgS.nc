/*
 * Copyright (c) 2012, Eric B. Decker
 * All rights reserved.
 *
 * GPSMsgS: GPSMsg interface, syncronous version.
 */

interface GPSMsgS {
  command void     reset();
  command uint16_t eavesIndex();
  command void     eavesDrop(uint8_t byte);
  command void     eavesDropBuffer(uint8_t *buf, uint16_t size);

  command bool     byteAvail(uint8_t byte);
  command uint16_t processBuffer(uint8_t *buf, uint16_t len);

  command bool     bufferAvail();
  command bool     atMsgBoundary();
  event   void     resume();
}
