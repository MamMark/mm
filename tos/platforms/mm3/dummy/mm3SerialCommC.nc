/**
 * Copyright @ 2008 Eric B. Decker
 * @author Eric B. Decker
 */
 
#include "sensors.h"

configuration mmSerialCommC {
  provides {
    interface Send[uint8_t id];
    interface AMPacket;
    interface Packet;
    interface SplitControl;
  }
}

implementation {
  components MainC;
  components mmSerialCommP;
  components new SerialAMSenderC(AM_MM_DT);
  components new AMQueueImplP(MM_NUM_SENSORS), SerialActiveMessageC;
  
  MainC.SoftwareInit -> mmSerialCommP;

  Send = AMQueueImplP;
  AMPacket = SerialAMSenderC;
  Packet = SerialAMSenderC;
  SplitControl = SerialActiveMessageC;
  
  mmSerialCommP.SubAMSend[AM_MM_DT] -> SerialAMSenderC;
  AMQueueImplP.AMSend -> mmSerialCommP.AMSend;
  AMQueueImplP.Packet -> SerialAMSenderC;
  AMQueueImplP.AMPacket -> SerialAMSenderC;
  
  components new NoArbiterC();
  mmSerialCommP.Resource -> NoArbiterC.Resource;
  
  components LedsC;
  mmSerialCommP.Leds -> LedsC;
}
