/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

/**
 * mm3CommData provides a data stream for data blocks.  Typed data
 * blocks as defined in sd_bocks.h.
 *
 * @author Eric B. Decker
 * @date   Apr 3 2008
 */ 

#include "AM.h"
#include "sensors.h"

module mm3CommDataP {
  provides {
    interface mm3CommData[uint8_t cid];
  }
  uses {
    interface Send[uint8_t cid];
    interface SendBusy[uint8_t cid];
    interface AMPacket;
    interface Packet;
    interface Panic;
    interface Leds;
  }
}

implementation {
  message_t data_msg[MM3_NUM_SENSORS];

#if NUM_SENSORS != 10
#warning "MM3_NUM_SENSORS/NUM_SENSORS is different than 10"
#endif

  message_t * const dm_p[NUM_SENSORS] = {
    &data_msg[0],
    &data_msg[1],
    &data_msg[2],
    &data_msg[3],
    &data_msg[4],
    &data_msg[5],
    &data_msg[6],
    &data_msg[7],
    &data_msg[8],
    &data_msg[9],
  };

  /*
   * Accepts a buffer formatted as a data block (see sd_blocks.h) and sends
   * it out the DATA port.
   *
   * It is assumed that a queued interface is used where one slot per
   * client is reserved.  So we want to check to make sure that the clients
   * slot is free before copying data into the message buffer.  The message
   * buffer could be busy and we would change the data out from underneath
   * it which would be bad.
   *
   * If the send returns SUCCESS will get a send_data_done signal back.
   */
  command error_t mm3CommData.send_data[uint8_t cid](void *buf, uint8_t len) {
    uint8_t *bp;
    message_t *dm;

    if (call SendBusy.busy[cid]())
      return EBUSY;
    dm = (void *) dm_p[cid];
    bp = call Packet.getPayload(dm, len);
    if (!dm || !bp) {
      call Panic.warn(PANIC_COMM, 10, (uint16_t) dm, (uint16_t) bp, 0, 0);
      return FAIL;
    }
    memcpy(bp, buf, len);
    call AMPacket.setType(dm, AM_MM3_DATA);
    call AMPacket.setDestination(dm, AM_BROADCAST_ADDR);
    return call Send.send[cid](dm, len);
  }

  event void Send.sendDone[uint8_t cid](message_t* msg, error_t err) {
    signal mm3CommData.send_data_done[cid](err);
  }

  default event void mm3CommData.send_data_done[uint8_t cid](error_t rtn) {
    call Panic.panic(PANIC_COMM, 11, 0, 0, 0, 0);
  }
}
