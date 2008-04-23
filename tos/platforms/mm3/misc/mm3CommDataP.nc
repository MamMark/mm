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

  /*
   * Accepts a buffer formatted as a data block (see sd_blocks.h) and sends
   * it out the DATA port.
   */
  command error_t mm3CommData.send_data[uint8_t client_id](void *buf, uint8_t len) {
    memcpy(call Packet.getPayload(&(data_msg[client_id]), len), buf, len);
    call AMPacket.setType(&(data_msg[client_id]), AM_MM3_DATA);
    call AMPacket.setDestination(&(data_msg[client_id]), AM_BROADCAST_ADDR);
    return call Send.send[client_id](&(data_msg[client_id]), len);
  }

  event void Send.sendDone[uint8_t client_id](message_t* msg, error_t err) {
    signal mm3CommData.send_data_done[client_id](err);
  }

  default event void mm3CommData.send_data_done[uint8_t client_id](error_t rtn) {
    call Panic.brk();
  }
}
