/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

/**
 * mm3Comm provides a single interface that can be switched between
 * the radio or the direct connect serial line.
 *
 * Each channel (control, debug, or data) contends for the comm line.
 * Data packets contend with each other before contending for the
 * comm line with control and debug traffic.
 *
 * @author Eric B. Decker
 * @date   Apr 3 2008
 */ 

#include "AM.h"
#include "sensors.h"

module mm3CommDataP {
  provides {
    interface mm3CommData[uint8_t client_id];
  }
  uses {
    interface Send[uint8_t client_id];
    interface AMPacket;
    interface Packet;
    interface Panic;
    interface Leds;
  }
}

implementation {
  message_t data_msg[MM3_NUM_SENSORS];
  message_t * const dm_p[MM3_NUM_SENSORS] = {
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
   * it out the DATA port.   Build a pointer to data_msg[client_id] to avoid math
   *
   * This should always cause the send_data_done.
   */
  command error_t mm3CommData.send_data[uint8_t client_id](void *buf, uint8_t len) {
    uint8_t *bp;
    message_t *dm;

    dm = (void *) dm_p[client_id];
    bp = call Packet.getPayload(dm, len);
    if (!dm || !bp) {
      call Panic.warn(PANIC_COMM, 10, (uint16_t) dm, (uint16_t) bp, 0, 0);
      return FAIL;
    }
    memcpy(bp, buf, len);
    call AMPacket.setType(dm, AM_MM3_DATA);
    call AMPacket.setDestination(dm, AM_BROADCAST_ADDR);
    return call Send.send[client_id](dm, len);
  }

  event void Send.sendDone[uint8_t client_id](message_t* msg, error_t err) {
    signal mm3CommData.send_data_done[client_id](err);
  }

  default event void mm3CommData.send_data_done[uint8_t client_id](error_t rtn) {
    call Panic.panic(PANIC_COMM, 11, 0, 0, 0, 0);
  }
}
