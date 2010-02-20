/*
 * Copyright (c) 2008, 2010 Eric B. Decker
 * All rights reserved.
 */

/**
 * @author Eric B. Decker (cire831@gmail.com)
 * @date 28 May 2008
 *
 * Handle processing cmds received on the command (control) channel.
 */

module CmdHandlerP {
  provides {
//    interface Init;
    interface StdControl as CmdControl;
  }
  uses {
//    interface Boot;
//    interface AMSend       as CmdAMSend;

    interface Receive      as CmdReceive;
    interface SplitControl as SerialControl;
    interface Leds;
  }
}

implementation {
//  event void Boot.booted() {
//    if (call SerialControl.start() != SUCCESS)
//      call Leds.set(7);
//  }

  
  command error_t CmdControl.start() {
    if (call SerialControl.start() != SUCCESS)
      call Leds.set(7);
    return SUCCESS;
  }

  event void SerialControl.startDone(error_t err) {
    if(err != SUCCESS)
      call Leds.set(7);
  }
	
  event void SerialControl.stopDone(error_t err) { }
	
  command error_t CmdControl.stop() {
    call SerialControl.stop();
    return SUCCESS;
  }

  event message_t * CmdReceive.receive(message_t * msg, void * payload, uint8_t len) {
    mm_control_msg_t * cmd_payload = payload;
    nop();
    return msg;
  }
}
