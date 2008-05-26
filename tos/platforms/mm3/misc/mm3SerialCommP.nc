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
    interface Init;
    interface AMSend[uint8_t id];
  }
  uses {
    interface Resource;
    interface ResourceRequested;
    interface AMSend as SubAMSend[uint8_t client_id];
    interface Leds;
  }
}

implementation {
  error_t busy = FALSE;
  
  command error_t Init.init() {
    return call Resource.immediateRequest();
  }

  command error_t AMSend.send[uint8_t id](am_addr_t addr, message_t *msg, uint8_t len) {
    error_t e;
    if(busy == FALSE) {
      if(call Resource.isOwner() == TRUE) {
        atomic busy = TRUE;
        if( (e = call SubAMSend.send[id](addr, msg, len)) != SUCCESS )
          atomic busy = FALSE;
        return e;
      }
      return FAIL;
    }
    return EBUSY;
  }

  event void Resource.granted() {}

  event void SubAMSend.sendDone[uint8_t id](message_t* msg, error_t err) {
    atomic busy = FALSE;
    signal AMSend.sendDone[id](msg, err);
  }
  
  command error_t AMSend.cancel[uint8_t id](message_t* msg) {
    error_t e = call SubAMSend.cancel[id](msg);
    if(e == SUCCESS) busy = FALSE;
    return e;
  }

  command uint8_t AMSend.maxPayloadLength[uint8_t id]() {
    return call SubAMSend.maxPayloadLength[id]();
  }

  command void* AMSend.getPayload[uint8_t id](message_t* msg, uint8_t len) {
    return call SubAMSend.getPayload[id](msg, len);
  }
  
  void requested() {
    if(!busy) {
      if(call Resource.isOwner() == TRUE) {
        call Resource.release();
        call Resource.request();
      } 
    }
  }
  
  async event void ResourceRequested.requested() {
    requested();
  }
  async event void ResourceRequested.immediateRequested() {
    requested();
  }

  default event void AMSend.sendDone[uint8_t id](message_t* msg, error_t err) {
  }

  default command error_t SubAMSend.send[uint8_t id](am_addr_t addr, message_t *msg, uint8_t len) {
    return FAIL;
  }
}
