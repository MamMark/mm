/**
 * Copyright @ 2008 Eric B. Decker
 * @author Eric B. Decker
 */
 
#include "sensors.h"

configuration mm3CommC {
  provides {
    interface mm3Comm;
    interface Send[uint8_t id];
    interface AMPacket;
    interface Packet;
  }
  uses {
    interface AsyncStdControl;
    interface ResourceDefaultOwner;
  }
}

implementation {
  components MainC;
  components mm3CommP;
  
  MainC.SoftwareInit -> mm3CommP;
  
  mm3Comm = mm3CommP;
  Send = mm3CommP;
  AMPacket = mm3CommP;
  Packet = mm3CommP;

  mm3CommP.AsyncStdControl = AsyncStdControl;
  mm3CommP.ResourceDefaultOwner = ResourceDefaultOwner;
  
  components mm3SerialCommC;
  mm3CommP.SerialSend -> mm3SerialCommC;
  mm3CommP.SerialAMPacket -> mm3SerialCommC;
  mm3CommP.SerialPacket -> mm3SerialCommC;
  mm3CommP.SerialAMControl -> mm3SerialCommC;
  
  components mm3RadioCommC;
  mm3CommP.RadioSend -> mm3RadioCommC;
  mm3CommP.RadioAMPacket -> mm3RadioCommC;
  mm3CommP.RadioPacket -> mm3RadioCommC;
  mm3CommP.RadioAMControl -> mm3RadioCommC;
  
  components PanicC;
  mm3CommP.Panic -> PanicC;
}
