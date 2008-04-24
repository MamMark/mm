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

module mm3SerialCommP {
  provides {
    interface Send[uint8_t id];
  }
  uses {
    interface Resource;
    interface Send as SubSend[uint8_t client_id];
  }
}

implementation {
  message_t* my_msg;
  uint8_t my_len;
  uint8_t my_id;
  error_t busy = FALSE;

  command error_t Send.send[uint8_t id](message_t *msg, uint8_t len) {
    if(busy == FALSE) {
      busy = TRUE;
      call Resource.request();
      my_msg = msg;
      my_len = len;
      my_id = id;
    }
    else return EBUSY;
  }
  event void Resource.granted() {
    error_t e;
    if( (e = call SubSend.send[my_id](my_msg, my_len)) != SUCCESS )
      signal Send.sendDone[my_id](my_msg, e);
  }

  event void SubSend.sendDone[uint8_t id](message_t* msg, error_t err) {
    signal Send.sendDone[id](msg, err);
  }
  
  command error_t Send.cancel[uint8_t id](message_t* msg) {
    return call SubSend.cancel[id](msg);
  }

  command uint8_t Send.maxPayloadLength[uint8_t id]() {
    return call SubSend.maxPayloadLength[id]();
  }

  command void* Send.getPayload[uint8_t id](message_t* msg, uint8_t len) {
    return call SubSend.getPayload[id](msg, len);
  }

  default event void Send.sendDone[uint8_t id](message_t* msg, error_t err) {
  }
  default command error_t SubSend.send[uint8_t id](message_t *msg, uint8_t len) {
    return FAIL;
  }
}
