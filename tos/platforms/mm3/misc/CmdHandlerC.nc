/*
 * Copyright (c) 2008 Eric B. Decker
 * All rights reserved.
 */

/**
 * @author Eric B. Decker (cire831@gmail.com)
 * @date 28 May 2008
 *
 * Handle processing cmds received on the command (control) channel.
 */

#include "mm3_control_msg.h"

configuration CmdHandlerC {
}

implementation {
  components CmdHandlerP, MainC;

  MainC.SoftwareInit -> CmdHandlerP;
  CmdHandlerP.Boot -> MainC;

//  components new SerialAMSenderC(AM_MM3_CONTROL_MSG);
//  CmdHandlerP.AMSend -> SerialAMSenderC;

  components new SerialAMReceiverC(AM_MM3_CONTROL_MSG);
  CmdHandlerP.Receive -> SerialAMReceiverC;
//  CmdHandlerP.Packet -> SerialAMSenderC;

  components SerialActiveMessageC;
  CmdHandlerP.SerialControl -> SerialActiveMessageC;

  components LedsC;
  CmdHandlerP.Leds -> LedsC;
}
