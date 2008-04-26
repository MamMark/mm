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
    interface AMSend[uint8_t id];
  }
  uses {
    interface Resource;
    interface AMSend as SubAMSend[uint8_t client_id];
    interface Leds;
  }
}

implementation {
  am_addr_t my_addr;
  message_t* my_msg;
  uint8_t my_len;
  uint8_t my_id;
  error_t busy = FALSE;
  
  void release() {
    busy = FALSE;
    call Resource.release();
  }

  command error_t AMSend.send[uint8_t id](am_addr_t addr, message_t *msg, uint8_t len) {
    if(busy == FALSE) {
      if(call Resource.request() == SUCCESS) {
        busy = TRUE;
        my_addr = addr;
        my_msg = msg;
        my_len = len;
        my_id = id;
        return SUCCESS;
      }
    }
    return EBUSY;
  }

  event void Resource.granted() {
    error_t e;
    if( (e = call SubAMSend.send[my_id](my_addr, my_msg, my_len)) != SUCCESS ) {
      release();
      signal AMSend.sendDone[my_id](my_msg, e);
    }
  }

  event void SubAMSend.sendDone[uint8_t id](message_t* msg, error_t err) {
    release();
    signal AMSend.sendDone[id](msg, err);
  }
  
  command error_t AMSend.cancel[uint8_t id](message_t* msg) {
    error_t e = call SubAMSend.cancel[id](msg);
    if(e == SUCCESS) release();
    return e;
  }

  command uint8_t AMSend.maxPayloadLength[uint8_t id]() {
    return call SubAMSend.maxPayloadLength[id]();
  }

  command void* AMSend.getPayload[uint8_t id](message_t* msg, uint8_t len) {
    return call SubAMSend.getPayload[id](msg, len);
  }

  default event void AMSend.sendDone[uint8_t id](message_t* msg, error_t err) {
  }

  default command error_t SubAMSend.send[uint8_t id](am_addr_t addr, message_t *msg, uint8_t len) {
    return FAIL;
  }
}
