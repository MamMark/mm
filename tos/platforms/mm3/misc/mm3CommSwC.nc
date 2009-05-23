/**
 * Copyright @ 2008-2009 Eric B. Decker
 * @author Eric B. Decker <cire831@gmail.com>
 */
 
#include "sensors.h"

configuration mm3CommSwC {
  provides {
    interface mm3CommSw;
    interface Send[uint8_t cid];
    interface SendBusy[uint8_t cid];
    interface AMPacket;
    interface Packet;
  }
//  uses {
//    interface AsyncStdControl;
//    interface ResourceDefaultOwner;
//  }
}

implementation {
  components mm3CommSwP;
  
  mm3CommSw  = mm3CommSwP;
  Send       = mm3CommSwP;
  SendBusy   = mm3CommSwP;
  AMPacket   = mm3CommSwP;
  Packet     = mm3CommSwP;

//  mm3CommSwP.AsyncStdControl = AsyncStdControl;
//  mm3CommSwP.ResourceDefaultOwner = ResourceDefaultOwner;
  
  components mm3SerialCommC;
  mm3CommSwP.SerialSend     -> mm3SerialCommC;
  mm3CommSwP.SerialSendBusy -> mm3SerialCommC;
  mm3CommSwP.SerialAMPacket -> mm3SerialCommC;
  mm3CommSwP.SerialPacket   -> mm3SerialCommC;
  mm3CommSwP.SerialAMControl-> mm3SerialCommC;

  components mm3RadioCommC;
  mm3CommSwP.RadioSend     -> mm3RadioCommC;
  mm3CommSwP.RadioSendBusy -> mm3RadioCommC;
  mm3CommSwP.RadioAMPacket -> mm3RadioCommC;
  mm3CommSwP.RadioPacket   -> mm3RadioCommC;
  mm3CommSwP.RadioAMControl-> mm3RadioCommC;

  components PanicC;
  mm3CommSwP.Panic -> PanicC;
}
