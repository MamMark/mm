/*
 * Copyright (c) 2008, 2010 Eric B. Decker
 * All rights reserved.
 */

/**
 * @author Eric B. Decker (cire831@gmail.com)
 * @date 13 Apr 2010
 *
 * Handle processing cmds received on the command (control) channel.
 */

#include "am_types.h"
#include "mm_control.h"

configuration CmdHandlerC {
  provides interface StdControl as CmdControl;
}

implementation {
  components CmdHandlerP;
  CmdControl = CmdHandlerP;

//  components CmdHandlerP, MainC;

//  MainC.SoftwareInit -> CmdHandlerP;
//  CmdHandlerP.Boot -> MainC;

//  components new SerialAMSenderC(AM_MM_CONTROL);
//  CmdHandlerP.AMSend -> SerialAMSenderC;

  components new SerialAMReceiverC(AM_MM_CONTROL);
  CmdHandlerP.CmdReceive -> SerialAMReceiverC;
//  CmdHandlerP.Packet -> SerialAMSenderC;

  components SerialActiveMessageC;
  CmdHandlerP.SerialControl -> SerialActiveMessageC;

  components LedsC;
  CmdHandlerP.Leds -> LedsC;
}
