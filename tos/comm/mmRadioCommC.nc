/**
 * Copyright @ 2008 Eric B. Decker
 * @author Eric B. Decker
 */
 
#include "sensors.h"
#include "am_types.h"

configuration mmRadioCommC {
  provides interface Send[uint8_t id];
  provides interface SendBusy[uint8_t id];
  provides interface AMPacket;
  provides interface Packet;
  provides interface SplitControl;
}

implementation {
  components new AMSenderC(AM_MM_DT);
  components new AMQueueImplP(MM_NUM_SENSORS), ActiveMessageC;

  Send = AMQueueImplP;
  SendBusy = AMQueueImplP;
  AMPacket = AMSenderC;
  Packet = AMSenderC;
  SplitControl = ActiveMessageC;
  
  AMQueueImplP.AMSend[AM_MM_DT] -> AMSenderC;
  AMQueueImplP.Packet -> AMSenderC;
  AMQueueImplP.AMPacket -> AMSenderC;
}
