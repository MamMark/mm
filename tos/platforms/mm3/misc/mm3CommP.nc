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

typedef enum {
  COMM_STATE_OFF         = 1,
  COMM_STATE_SERIAL_REQUEST,
  COMM_STATE_SERIAL_INIT,
  COMM_STATE_SERIAL,
  COMM_STATE_SERIAL_RELEASED,
  COMM_STATE_RADIO_REQUEST,
  COMM_STATE_RADIO_INIT,
  COMM_STATE_RADIO,
} comm_state_t;


module mm3CommP {
  provides {
    interface Init;
    interface mm3Comm;
    interface Send[uint8_t id];
    interface Receive[uint8_t id];
    interface AMPacket;
    interface Packet;
  }
  uses {
    interface Panic;
  
    interface SplitControl as SerialAMControl;
    interface Send         as SerialSend[uint8_t id];
    interface Receive      as SerialReceive[uint8_t id];
    interface Packet	   as SerialPacket;
    interface AMPacket	   as SerialAMPacket;
    
    interface SplitControl as RadioAMControl;
    interface Send         as RadioSend[uint8_t id];
    interface Receive      as RadioReceive[uint8_t id];
    interface Packet	   as RadioPacket;
    interface AMPacket	   as RadioAMPacket;

    interface ResourceDefaultOwner;
    interface AsyncStdControl;
  }
}

implementation {

  comm_state_t comm_state;

  command error_t Init.init() {
    comm_state = COMM_STATE_OFF;
    return SUCCESS;
  }

  //********************* Use SERIAL *******************************//

  command error_t mm3Comm.useSerial() {
    if (comm_state == COMM_STATE_SERIAL)
      return EALREADY;
    if (comm_state == COMM_STATE_OFF || comm_state == COMM_STATE_RADIO) {
      comm_state = COMM_STATE_SERIAL_INIT;
      call SerialAMControl.start();
      return SUCCESS;
    } 
    return EBUSY;
  }

  event void SerialAMControl.startDone(error_t error) {
    if (error == SUCCESS) {
      comm_state = COMM_STATE_SERIAL; 
      signal mm3Comm.serialOn();
    } else {
      call Panic.brk(0);
      call SerialAMControl.start();
    }
  }
  
  //********************* Use RADIO *******************************//

  command error_t mm3Comm.useRadio() {
    if(comm_state == COMM_STATE_RADIO)
      return EALREADY;
    if(comm_state == COMM_STATE_OFF || comm_state == COMM_STATE_SERIAL) {
      comm_state = COMM_STATE_RADIO_INIT;
      call RadioAMControl.start();
      return SUCCESS;
    } 
    return EBUSY;
  }

  event void RadioAMControl.startDone(error_t error) {
    if(error == SUCCESS) {
      comm_state = COMM_STATE_RADIO; 
      signal mm3Comm.radioOn();
    } else {
      call Panic.brk(0);
      call RadioAMControl.start();
    }
  }
  
  //********************* Use NONE *******************************//

  command error_t mm3Comm.useNone() {
    if(comm_state == COMM_STATE_OFF)
      return EALREADY;
    if(comm_state == COMM_STATE_SERIAL) {
      comm_state = COMM_STATE_SERIAL_INIT;
      call SerialAMControl.stop();
      return SUCCESS;
    } 
    if(comm_state == COMM_STATE_RADIO) {
      comm_state = COMM_STATE_RADIO_INIT;
      call RadioAMControl.stop();
      return SUCCESS;
    } else
      return EBUSY;
  }

  event void SerialAMControl.stopDone(error_t error) {
    if(error == SUCCESS) {
      comm_state = COMM_STATE_OFF; 
      signal mm3Comm.commOff();
    } else {
      call Panic.brk(0);
      call SerialAMControl.stop();
    }
  }

  event void RadioAMControl.stopDone(error_t error) {
    if(error == SUCCESS) {
      comm_state = COMM_STATE_OFF; 
      signal mm3Comm.commOff();
    } else {
      call Panic.brk(0);
      call RadioAMControl.stop();
    }
  }

  //********************* Receiving *******************************//

  event message_t* SerialReceive.receive[uint8_t id](message_t* msg, void* payload, uint8_t len) {
    return signal Receive.receive[id](msg, payload, len);
  }

  event message_t* RadioReceive.receive[uint8_t id](message_t* msg, void* payload, uint8_t len) {
    return signal Receive.receive[id](msg, payload, len);
  }

  //********************* Sending *******************************//

  command error_t Send.send[uint8_t id](message_t* msg, uint8_t len) {
    switch (comm_state) {
      case COMM_STATE_OFF:
	return EOFF;  
      case COMM_STATE_SERIAL_INIT:
      case COMM_STATE_RADIO_INIT:
	return EBUSY;
      case COMM_STATE_SERIAL:
	return call SerialSend.send[id](msg, len);
      case COMM_STATE_RADIO:
	return call RadioSend.send[id](msg, len);
      default:
	call Panic.brk(0);
	return FAIL;
    }
  }

  command error_t Send.cancel[uint8_t id](message_t* msg) {
    switch (comm_state) {
      case COMM_STATE_OFF:
	return EOFF;  
      case COMM_STATE_SERIAL_INIT:
      case COMM_STATE_RADIO_INIT:
	return EBUSY;
      case COMM_STATE_SERIAL:
	return call SerialSend.cancel[id](msg);
      case COMM_STATE_RADIO:
	return call RadioSend.cancel[id](msg);
      default:
	call Panic.brk(0);
	return FAIL;
    }  
  }

  event void SerialSend.sendDone[uint8_t id](message_t* msg, error_t error) {
    signal Send.sendDone[id](msg, error);
  }
  
  event void RadioSend.sendDone[uint8_t id](message_t* msg, error_t error) {
    signal Send.sendDone[id](msg, error);
  }

  command uint8_t Send.maxPayloadLength[uint8_t id]() {
    switch (comm_state) {
      case COMM_STATE_SERIAL:
	return call SerialSend.maxPayloadLength[id]();
      case COMM_STATE_RADIO:
	return call RadioSend.maxPayloadLength[id]();
      default:
	call Panic.brk(0);
	return -1;
    }
  }


  command void* Send.getPayload[uint8_t id](message_t* msg, uint8_t len) {
    switch (comm_state) {
      case COMM_STATE_SERIAL:
	return call SerialSend.getPayload[id](msg, len);
      case COMM_STATE_RADIO:
	return call RadioSend.getPayload[id](msg, len);
      default:
	call Panic.brk(0);
	return NULL;
    }
  }


  command am_addr_t AMPacket.address() {
    switch (comm_state) {
      case COMM_STATE_SERIAL:
	return call SerialAMPacket.address();
      case COMM_STATE_RADIO:
	return call RadioAMPacket.address();
      default:
	call Panic.brk(0);
	return -1;
    }  
  }


  command am_addr_t AMPacket.destination(message_t* amsg) {
    switch (comm_state) {
      case COMM_STATE_SERIAL:
	return call SerialAMPacket.destination(amsg);
      case COMM_STATE_RADIO:
	return call RadioAMPacket.destination(amsg);
      default:
	call Panic.brk(0);
	return -1;
    }    
  }


  command am_addr_t AMPacket.source(message_t* amsg) {
    switch (comm_state) {
      case COMM_STATE_SERIAL:
	return call SerialAMPacket.source(amsg);
      case COMM_STATE_RADIO:
	return call RadioAMPacket.source(amsg);
      default:
	call Panic.brk(0);
	return -1;
    }    
  }


  command void AMPacket.setDestination(message_t* amsg, am_addr_t addr) {
    switch (comm_state) {
      case COMM_STATE_SERIAL:
	call SerialAMPacket.setDestination(amsg, addr);
	return;
      case COMM_STATE_RADIO:
	call RadioAMPacket.setDestination(amsg, addr);
	return;
      default:
	call Panic.brk(0);
	return;
    }   
  }


  command void AMPacket.setSource(message_t* amsg, am_addr_t addr) {
    switch (comm_state) {
      case COMM_STATE_SERIAL:
	call SerialAMPacket.setSource(amsg, addr);
	return;
      case COMM_STATE_RADIO:
	call RadioAMPacket.setSource(amsg, addr);
	return;
      default:
	call Panic.brk(0);
	return;
    }   
  }


  command bool AMPacket.isForMe(message_t* amsg) {
    switch (comm_state) {
      case COMM_STATE_SERIAL:
	return call SerialAMPacket.isForMe(amsg);
      case COMM_STATE_RADIO:
	return call RadioAMPacket.isForMe(amsg);
      default:
	call Panic.brk(0);
	return FALSE;
    } 
  }


  command am_id_t AMPacket.type(message_t* amsg) {
    switch (comm_state) {
      case COMM_STATE_SERIAL:
	return call SerialAMPacket.type(amsg);
      case COMM_STATE_RADIO:
	return call RadioAMPacket.type(amsg);
      default:
	call Panic.brk(0);
	return -1;
    }  
  }


  command void AMPacket.setType(message_t* amsg, am_id_t t) {
    switch (comm_state) {
      case COMM_STATE_SERIAL:
	call SerialAMPacket.setType(amsg, t);
	return;
      case COMM_STATE_RADIO:
	call RadioAMPacket.setType(amsg, t);
	return;
      default:
	call Panic.brk(0);
	return;
    } 
  }


  command am_group_t AMPacket.group(message_t* amsg) {
    switch (comm_state) {
      case COMM_STATE_SERIAL:
	return call SerialAMPacket.group(amsg);
      case COMM_STATE_RADIO:
	return call RadioAMPacket.group(amsg);
      default:
	call Panic.brk(0);
	return -1;
    } 
  }


  command void AMPacket.setGroup(message_t* amsg, am_group_t grp) {
    switch (comm_state) {
      case COMM_STATE_SERIAL:
	call SerialAMPacket.setGroup(amsg, grp);
	return;
      case COMM_STATE_RADIO:
	call RadioAMPacket.setGroup(amsg, grp);
	return;
      default:
	call Panic.brk(0);
	return;
    } 
  }


  command am_group_t AMPacket.localGroup() {
    switch (comm_state) {
      case COMM_STATE_SERIAL:
	return call SerialAMPacket.localGroup();
      case COMM_STATE_RADIO:
	return call RadioAMPacket.localGroup();
      default:
	call Panic.brk(0);
	return -1;
    }
  }


  command void Packet.clear(message_t* msg) {
    switch (comm_state) {
      case COMM_STATE_SERIAL:
	call SerialPacket.clear(msg);
	return;
      case COMM_STATE_RADIO:
	call RadioPacket.clear(msg);
	return;
      default:
	call Panic.brk(0);
	return;
    }
  }


  command uint8_t Packet.payloadLength(message_t* msg) {
    switch (comm_state) {
      case COMM_STATE_SERIAL:
	return call SerialPacket.payloadLength(msg);
      case COMM_STATE_RADIO:
	return call RadioPacket.payloadLength(msg);
      default:
	call Panic.brk(0);
	return -1;
    }  
  }

  command void Packet.setPayloadLength(message_t* msg, uint8_t len) {
    switch (comm_state) {
      case COMM_STATE_SERIAL:
	call SerialPacket.setPayloadLength(msg, len);
	return;
      case COMM_STATE_RADIO:
	call RadioPacket.setPayloadLength(msg, len);
	return;
      default:
	call Panic.brk(0);
	return;
    }  
  }

  command uint8_t Packet.maxPayloadLength() {
    switch (comm_state) {
      case COMM_STATE_SERIAL:
	return call SerialPacket.maxPayloadLength();
      case COMM_STATE_RADIO:
	return call RadioPacket.maxPayloadLength();
      default:
	call Panic.brk(0);
	return -1;
    }  
  }

  command void* Packet.getPayload(message_t* msg, uint8_t len) {
    switch (comm_state) {
      case COMM_STATE_SERIAL:
	return call SerialPacket.getPayload(msg, len);
      case COMM_STATE_RADIO:
	return call RadioPacket.getPayload(msg, len);
      default:
	call Panic.brk(0);
	return NULL;
    }  
  }

  /* ************* Default Ownership Control ****************** */

  async event void ResourceDefaultOwner.requested() {
    call AsyncStdControl.start();
    call ResourceDefaultOwner.release(); 
  }

  async event void ResourceDefaultOwner.immediateRequested() {
    call AsyncStdControl.start();
    call ResourceDefaultOwner.release();
  } 

  async event void ResourceDefaultOwner.granted() {
    call AsyncStdControl.stop();
  }

}
