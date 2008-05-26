/**
 * Copyright @ 2008 Eric B. Decker
 * @author Eric B. Decker
 */
 
#include "sensors.h"

configuration mm3SerialCommC {
  provides {
    interface Send[uint8_t id];
    interface AMPacket;
    interface Packet;
    interface SplitControl;
  }
  uses {
    interface Resource;
    interface ResourceRequested;
  }
}

implementation {
  components MainC;
  components mm3SerialCommP;
  components new SerialAMSenderC(AM_MM3_DATA);
  components new AMQueueImplP(MM3_NUM_SENSORS), SerialActiveMessageC;
  
  MainC.SoftwareInit -> mm3SerialCommP;

  Send = AMQueueImplP;
  Resource = mm3SerialCommP;
  ResourceRequested = mm3SerialCommP;
  AMPacket = SerialAMSenderC;
  Packet = SerialAMSenderC;
  SplitControl = SerialActiveMessageC;
  
  mm3SerialCommP.SubAMSend[AM_MM3_DATA] -> SerialAMSenderC;
  AMQueueImplP.AMSend -> mm3SerialCommP.AMSend;
  AMQueueImplP.Packet -> SerialAMSenderC;
  AMQueueImplP.AMPacket -> SerialAMSenderC;
  
  components LedsC;
  mm3SerialCommP.Leds -> LedsC;
}
