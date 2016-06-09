/*
 * Currently not used.
 *
 * Copyright (c) 2012 Eric B. Decker
 * All rights reserved.
 *
 * GpsMsgBuffer: Buffer interface, Synchronous.
 */

#include "GpsMsgBuffer.h"

interface GpsMsgBuffer {
  command void bufferFree(gps_buf_t *buf);
  event   void bufferAvail(gps_buf_t *buf);
}
