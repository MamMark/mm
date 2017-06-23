/**
 * Copyright @ 2008-2010 Eric B. Decker
 * @author Eric B. Decker <cire831@gmail.com>
 */
 
#include "sensors.h"

configuration mmCommSwC {
  provides {
    interface mmCommSw;
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
  components mmCommSwP;
  
  mmCommSw   = mmCommSwP;
  Send       = mmCommSwP;
  SendBusy   = mmCommSwP;
  AMPacket   = mmCommSwP;
  Packet     = mmCommSwP;

//  mmCommSwP.AsyncStdControl = AsyncStdControl;
//  mmCommSwP.ResourceDefaultOwner = ResourceDefaultOwner;
  
  components DockCommArbiterC;
  mmCommSwP.SerialSend     -> DockCommArbiterC;
  mmCommSwP.SerialSendBusy -> DockCommArbiterC;
  mmCommSwP.SerialAMPacket -> DockCommArbiterC;
  mmCommSwP.SerialPacket   -> DockCommArbiterC;
  mmCommSwP.SerialAMControl-> DockCommArbiterC;

  components mmRadioCommC;
  mmCommSwP.RadioSend     -> mmRadioCommC;
  mmCommSwP.RadioSendBusy -> mmRadioCommC;
  mmCommSwP.RadioAMPacket -> mmRadioCommC;
  mmCommSwP.RadioPacket   -> mmRadioCommC;
  mmCommSwP.RadioAMControl-> mmRadioCommC;

  components PanicC;
  mmCommSwP.Panic -> PanicC;
}
