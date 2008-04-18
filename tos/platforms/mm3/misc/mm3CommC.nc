/**
 * Copyright @ 2008 Eric B. Decker
 * @author Eric B. Decker
 */

configuration mm3CommC {
  provides interface Send;
  provides interface AMPacket;
  provides interface Packet;
  provides interface SplitControl as mm3CommSerCtl;
}

implementation {
  components mm3CommP;
  Send     = mm3CommP;
  Packet   = mm3CommP;
  AMPacket = mm3CommP;
  mm3CommSerCtl = mm3CommP;

  components MainC;
  MainC.SoftwareInit -> mm3CommP;

  //  components new SerialAMSenderC(AM_MM3_CONTROL)   as SendCtlC;
  components new SerialAMSenderC(AM_MM3_DATA)      as SendDataC;
  //  components new SerialAMSenderC(AM_MM3_DEBUG)     as SendDebugC;
  //  mm3CommP.SendCtl  -> SendCtlC.AMSend;
  mm3CommP.SerialAMSend   -> SendDataC.AMSend;
  mm3CommP.SerialAMPacket -> SendDataC.AMPacket;
  mm3CommP.SerialPacket   -> SendDataC.Packet;
  //  mm3CommP.SendDebug-> SendDebugC.AMSend;

  //  components new SerialAMReceiverC(AM_MM3_CONTROL) as RecvCtlC;
  components new SerialAMReceiverC(AM_MM3_DATA)    as RecvDataC;
  //  components new SerialAMReceiverC(AM_MM3_DEBUG)   as RecvDebugC;
  //  mm3CommP.RecvCtl  -> RecvCtlC.Receive;
  mm3CommP.SerialReceive -> RecvDataC.Receive;
  //  mm3CommP.RecvDebug-> RecvDebugC.Receive;

  components SerialActiveMessageC;
  mm3CommP.SerialAMControl -> SerialActiveMessageC;

  components PanicC;
  mm3CommP.Panic -> PanicC;
}
