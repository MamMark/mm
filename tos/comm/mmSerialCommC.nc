/**
 * Copyright @ 2008, 2010 Eric B. Decker
 * @author Eric B. Decker
 */
 
#include "sensors.h"

configuration mmSerialCommC {
  provides {
    interface Send[uint8_t id];
    interface SendBusy[uint8_t id];
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
  components mmSerialCommP;
  components new SerialAMSenderC(AM_MM_DATA);
  components new AMQueueImplP(MM_NUM_SENSORS), SerialActiveMessageC;
  
  MainC.SoftwareInit -> mmSerialCommP;

  Send = AMQueueImplP;
  SendBusy = AMQueueImplP;
  Resource = mmSerialCommP;
  ResourceRequested = mmSerialCommP;
  AMPacket = SerialAMSenderC;
  Packet = SerialAMSenderC;
  SplitControl = SerialActiveMessageC;
  
  mmSerialCommP.SubAMSend[AM_MM_DATA] -> SerialAMSenderC;
  AMQueueImplP.AMSend -> mmSerialCommP.AMSend;
  AMQueueImplP.Packet -> SerialAMSenderC;
  AMQueueImplP.AMPacket -> SerialAMSenderC;
  
  components LedsC;
  mmSerialCommP.Leds -> LedsC;
}
