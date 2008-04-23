/**
 * Copyright @ 2008 Eric B. Decker
 * @author Eric B. Decker
 */
 
#include "sensors.h"

configuration mm3SerialCommC {
  provides interface Send[uint8_t id];
  provides interface AMPacket;
  provides interface Packet;
  provides interface SplitControl;
}

implementation {
  components new SerialAMSenderC(AM_MM3_DATA);
  components new AMQueueImplP(MM3_NUM_SENSORS), SerialActiveMessageC;

  Send = AMQueueImplP;
  AMPacket = SerialAMSenderC;
  Packet = SerialAMSenderC;
  SplitControl = SerialActiveMessageC;
  
  AMQueueImplP.AMSend[AM_MM3_DATA] -> SerialAMSenderC;
  AMQueueImplP.Packet -> SerialAMSenderC;
  AMQueueImplP.AMPacket -> SerialAMSenderC;
}
