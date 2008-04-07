/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 *
 * Provides multiplexing from the 3 MM3 comm streams (Control,
 * Debug, and Data) onto either the Radio stack or the serial
 * stack depending on how the tag is interconnected.
 */

/**
 * mm3Comm provides a single interface that can be switched between
 * the radio or the direct connect serial line.
 *
 * Control packets:
 *
 * Debug packets:
 *
 * Data packets:  Data packets are currently just used for sending
 * sensor eavesdrops.  Space is allocated for each sensor to have
 * at most one eavesdrop packet outstanding at any time.  See mm3CommData
 * where this is implemented.
 *
 * Each channel (control, debug, or data) contends for the comm line.
 * Data packets contend with each other before contending for the
 * comm line with control and debug traffic.
 *
 * @author Eric B. Decker
 * @date   Apr 3 2008
 */ 

#include "AM.h"
#include "Serial.h"
#include "sensors.h"

module mm3CommP {
  provides {
    interface SplitControl as mm3CommSerCtl;
    interface Send;
    interface AMPacket;
    interface Packet;
    interface Init;
  }
  uses {
    interface Panic;
    interface SplitControl as SerialAMControl;
    interface AMSend       as SerialAMSend;
    interface Receive      as SerialReceive;
    interface Packet	   as SerialPacket;
    interface AMPacket	   as SerialAMPacket;
  }
}

implementation {

  enum {
    COMM_STATE_OFF	  = 1,
    COMM_STATE_SERIAL_INIT= 2,
    COMM_STATE_SERIAL	  = 3,
    COMM_STATE_RADIO_INIT = 4,
    COMM_STATE_RADIO	  = 5,
  };

  uint8_t comm_state;
  
  command error_t Init.init() {
    comm_state = COMM_STATE_OFF;
    return SUCCESS;
  }


  command error_t mm3CommSerCtl.start() {
    if (comm_state == COMM_STATE_OFF) {
      comm_state = COMM_STATE_SERIAL_INIT;
      call SerialAMControl.start();
      return SUCCESS;
    } else
      return EBUSY;
  }


  command error_t mm3CommSerCtl.stop() {
    return SUCCESS;
  }


  event void SerialAMControl.startDone(error_t error) {
    if (error == SUCCESS) {
      comm_state = COMM_STATE_SERIAL;
      signal mm3CommSerCtl.startDone(error);
    } else {
      call Panic.brk();
      comm_state = COMM_STATE_SERIAL_INIT;
      call SerialAMControl.start();
    }
  }

  event void SerialAMControl.stopDone(error_t error) {
  }


  command error_t Send.send(message_t* msg, uint8_t len) {
    switch (comm_state) {
      case COMM_STATE_OFF:
	return EOFF;

      case COMM_STATE_SERIAL_INIT:
      case COMM_STATE_RADIO_INIT:
	call Panic.brk();
	return EOFF;

      case COMM_STATE_SERIAL:
	return call SerialAMSend.send(call AMPacket.destination(msg), msg, len);

      case COMM_STATE_RADIO:
	return FAIL;

      default:
	call Panic.brk();
	return FAIL;
    }
  }


  command error_t Send.cancel(message_t* msg) {
    return SUCCESS;
  }


  event void SerialAMSend.sendDone(message_t* msg, error_t error) {
    /*
     * Fix this.  the signal needs to go back to the appropriate
     * client.  ie.  if the msg is DATA it should go to the data
     * client.
     *
     * we could use the unique mechanism.
     */
    signal Send.sendDone(msg, error);
  }


  command uint8_t Send.maxPayloadLength() {
    switch(comm_state) {
      case COMM_STATE_OFF:
      case COMM_STATE_SERIAL_INIT:
      case COMM_STATE_RADIO_INIT:
	call Panic.brk();
	return 0;

      case COMM_STATE_SERIAL:
	return call SerialAMSend.maxPayloadLength();

      case COMM_STATE_RADIO:
	return 0;
    }
  }


  command void* Send.getPayload(message_t* msg, uint8_t len) {
    switch(comm_state) {
      case COMM_STATE_OFF:
      case COMM_STATE_SERIAL_INIT:
      case COMM_STATE_RADIO_INIT:
	call Panic.brk();
	return 0;

      case COMM_STATE_SERIAL:
	return call SerialAMSend.getPayload(msg, len);

      case COMM_STATE_RADIO:
	return 0;
    }
  }


  command am_addr_t AMPacket.address() {
    return call SerialAMPacket.address();
  }


  command am_addr_t AMPacket.destination(message_t* amsg) {
    return call SerialAMPacket.destination(amsg);
  }


  command am_addr_t AMPacket.source(message_t* amsg) {
    return call SerialAMPacket.source(amsg);
  }


  command void AMPacket.setDestination(message_t* amsg, am_addr_t addr) {
    call SerialAMPacket.setDestination(amsg, addr);
  }


  command void AMPacket.setSource(message_t* amsg, am_addr_t addr) {
    call SerialAMPacket.setSource(amsg, addr);
  }


  command bool AMPacket.isForMe(message_t* amsg) {
    return call SerialAMPacket.isForMe(amsg);
  }


  command am_id_t AMPacket.type(message_t* amsg) {
    return call SerialAMPacket.type(amsg);
  }


  command void AMPacket.setType(message_t* amsg, am_id_t t) {
    call SerialAMPacket.setType(amsg, t);
  }


  command am_group_t AMPacket.group(message_t* amsg) {
    return call SerialAMPacket.group(amsg);
  }


  command void AMPacket.setGroup(message_t* amsg, am_group_t grp) {
    call SerialAMPacket.setGroup(amsg, grp);
  }


  command am_group_t AMPacket.localGroup() {
    return call SerialAMPacket.localGroup();
  }


  command void Packet.clear(message_t* msg) {
    call SerialPacket.clear(msg);
  }


  command uint8_t Packet.payloadLength(message_t* msg) {
    return call SerialPacket.payloadLength(msg);
  }


  command void Packet.setPayloadLength(message_t* msg, uint8_t len) {
    call SerialPacket.setPayloadLength(msg, len);
  }


  command uint8_t Packet.maxPayloadLength() {
    return call SerialPacket.maxPayloadLength();
  }


  command void* Packet.getPayload(message_t* msg, uint8_t len) {
    return call SerialPacket.getPayload(msg, len);
  }


  event message_t *SerialReceive.receive(message_t *msg, void *payload, uint8_t len) {
    return msg;
  }


#ifdef notdef
  void sendDone(uint8_t last, message_t *msg, error_t err) {
    queue[last].msg = NULL;
    tryToSend();
    signal mm3CommData.send_data_done[last](err);
  }

  event void SerialSend.sendDone(message_t* msg, error_t err) {
    if (outCur >= DATA_OUT_CLIENTS) {
      return;
    }
    if(queue[current].msg == msg) {
      sendDone(current, msg, err);
    }
    else {
      dbg("PointerBug", "%s received send done for %p, signaling for %p.\n",
	  __FUNCTION__, msg, queue[current].msg);
    }
  }
    
    /**
     * Accepts a properly formatted AM packet for later sending.
     * Assumes that someone has filled in the AM packet fields
     * (destination, AM type).
     *
     * @param msg - the message to send
     * @param len - the length of the payload
     *
     */
    command error_t Send.send[uint8_t clientId](message_t* msg,
                                                uint8_t len) {
        if (clientId >= numClients) {
            return FAIL;
        }
        if (queue[clientId].msg != NULL) {
            return EBUSY;
        }
        dbg("AMQueue", "AMQueue: request to send from %hhu (%p): passed checks\n", clientId, msg);
        
        queue[clientId].msg = msg;
        call Packet.setPayloadLength(msg, len);
    
        if (current >= numClients) { // queue empty
            error_t err;
            am_id_t amId = call AMPacket.type(msg);
            am_addr_t dest = call AMPacket.destination(msg);
      
            dbg("AMQueue", "%s: request to send from %hhu (%p): queue empty\n", __FUNCTION__, clientId, msg);
            current = clientId;
            
            err = call AMSend.send[amId](dest, msg, len);
            if (err != SUCCESS) {
                dbg("AMQueue", "%s: underlying send failed.\n", __FUNCTION__);
                current = numClients;
                queue[clientId].msg = NULL;
                
            }
            return err;
        }
        else {
            dbg("AMQueue", "AMQueue: request to send from %hhu (%p): queue not empty\n", clientId, msg);
        }
        return SUCCESS;
    }

    task void CancelTask() {
        uint8_t i,j,mask,last;
        message_t *msg;
        for(i = 0; i < numClients/8 + 1; i++) {
            if(cancelMask[i]) {
                for(mask = 1, j = 0; j < 8; j++) {
                    if(cancelMask[i] & mask) {
                        last = i*8 + j;
                        msg = queue[last].msg;
                        queue[last].msg = NULL;
                        cancelMask[i] &= ~mask;
                        signal Send.sendDone[last](msg, ECANCEL);
                    }
                    mask <<= 1;
                }
            }
        }
    }
    
    command error_t Send.cancel[uint8_t clientId](message_t* msg) {
        if (clientId >= numClients ||         // Not a valid client    
            queue[clientId].msg == NULL ||    // No packet pending
            queue[clientId].msg != msg) {     // Not the right packet
            return FAIL;
        }
        if(current == clientId) {
            am_id_t amId = call AMPacket.type(msg);
            error_t err = call AMSend.cancel[amId](msg);
            return err;
        }
        else {
            cancelMask[clientId/8] |= 1 << clientId % 8;
            post CancelTask();
            return SUCCESS;
        }
    }

    void sendDone(uint8_t last, message_t *msg, error_t err) {
        queue[last].msg = NULL;
        tryToSend();
        signal Send.sendDone[last](msg, err);
    }

    task void errorTask() {
        sendDone(current, queue[current].msg, FAIL);
    }

    event void AMSend.sendDone[am_id_t id](message_t* msg, error_t err) {
      // Bug fix from John Regehr: if the underlying radio mixes things
      // up, we don't want to read memory incorrectly. This can occur
      // on the mica2.
      // Note that since all AM packets go through this queue, this
      // means that the radio has a problem. -pal
      if (current >= numClients) {
	return;
      }
      if(queue[current].msg == msg) {
	sendDone(current, msg, err);
      }
      else {
	dbg("PointerBug", "%s received send done for %p, signaling for %p.\n",
	    __FUNCTION__, msg, queue[current].msg);
      }
    }
    
    command uint8_t Send.maxPayloadLength[uint8_t id]() {
        return call AMSend.maxPayloadLength[0]();
    }

    command void* Send.getPayload[uint8_t id](message_t* m, uint8_t len) {
      return call AMSend.getPayload[0](m, len);
    }

    default event void Send.sendDone[uint8_t id](message_t* msg, error_t err) {
        // Do nothing
    }

  task void outSendTask();

  event void SerialAMControl.startDone(error_t error) {
  }

  event void SerialAMControl.stopDone(error_t error) {}

  message_t* receive(message_t* msg, void* payload, uint8_t len);
  
  event message_t *RadioSnoop.receive[am_id_t id](message_t *msg, void *payload, uint8_t len) {
    return receive(msg, payload, len);
  }
  
  message_t* receive(message_t *msg, void *payload, uint8_t len) {
    message_t *ret = msg;

    atomic {
      if (!inFull) {
	ret = inQueue[inNxt];
	inQueue[inNxt] = msg;

	inNxt = (inNxt + 1) % INBOUND_CLIENTS;
	
	if (inNxt == inEmpty)
	  inFull = TRUE;

	if (!inBusy) {
	  post uartSendTask();
	  inBusy = TRUE;
	}
      }
    }
    return ret;
  }

#endif

}
