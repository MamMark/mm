/*
 * Copyright (c) 2008, 2010-2011 Eric B. Decker
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
  components   CmdHandlerP;
  CmdControl = CmdHandlerP;

//  components MainC;

//  MainC.SoftwareInit -> CmdHandlerP;
//  CmdHandlerP.Boot -> MainC;

  components new TimerMilliC();
  CmdHandlerP.Timer -> TimerMilliC;

  components new SerialAMSenderC(AM_MM_CONTROL);
  CmdHandlerP.AMSend   -> SerialAMSenderC;
  CmdHandlerP.AMPacket -> SerialAMSenderC;
  CmdHandlerP.Packet   -> SerialAMSenderC;

  components new SerialAMReceiverC(AM_MM_CONTROL);
  CmdHandlerP.CmdReceive -> SerialAMReceiverC;

  components SerialActiveMessageC;
  CmdHandlerP.SerialControl -> SerialActiveMessageC;

  components LedsC;
  CmdHandlerP.Leds -> LedsC;
}
