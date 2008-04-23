/**
 * Copyright @ 2008 Eric B. Decker
 * @author Eric B. Decker
 */
 
#include "sensors.h"

configuration mm3RadioCommC {
  provides interface Send[uint8_t id];
  provides interface AMPacket;
  provides interface Packet;
  provides interface SplitControl;
}

implementation {
  components new AMSenderC(AM_MM3_DATA);
  components new AMQueueImplP(MM3_NUM_SENSORS), ActiveMessageC;

  Send = AMQueueImplP;
  AMPacket = AMSenderC;
  Packet = AMSenderC;
  SplitControl = ActiveMessageC;
  
  AMQueueImplP.AMSend[AM_MM3_DATA] -> AMSenderC;
  AMQueueImplP.Packet -> AMSenderC;
  AMQueueImplP.AMPacket -> AMSenderC;
}
