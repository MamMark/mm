/*
 * Copyright (c) 2008 Eric B. Decker
 * All rights reserved.
 */

/**
 * @author Eric B. Decker (cire831@gmail.com)
 * @date 20 Jan 2009
 *
 * Handle processing cmds received on the command (control) channel.
 */

#include "mm3_control_msg.h"

configuration CmdHandlerC {
  provides interface StdControl as CmdControl;
}

implementation {
  components CmdHandlerP;
  CmdControl = CmdHandlerP;

//  components CmdHandlerP, MainC;

//  MainC.SoftwareInit -> CmdHandlerP;
//  CmdHandlerP.Boot -> MainC;

//  components new SerialAMSenderC(AM_MM_CONTROL_MSG);
//  CmdHandlerP.AMSend -> SerialAMSenderC;

  components new SerialAMReceiverC(AM_MM_CONTROL_MSG);
  CmdHandlerP.CmdReceive -> SerialAMReceiverC;
//  CmdHandlerP.Packet -> SerialAMSenderC;

  components SerialActiveMessageC;
  CmdHandlerP.SerialControl -> SerialActiveMessageC;

  components LedsC;
  CmdHandlerP.Leds -> LedsC;
}
