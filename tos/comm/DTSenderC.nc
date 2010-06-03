/**
 * Copyright @ 2008, 2010 Eric B. Decker
 * @author Eric B. Decker
 */

#include "am_types.h"

configuration DTSenderC {
  provides interface DTSender[uint8_t sns_id];
}

implementation {
  components DTSenderP, MainC;
  DTSender = DTSenderP;

  components new SerialAMSenderC(AM_MM_DT);
  DTSenderP.AMSend -> SerialAMSenderC;
  DTSenderP.Packet -> SerialAMSenderC;

  components PanicC;
  DTSenderP.Panic -> PanicC;
}
