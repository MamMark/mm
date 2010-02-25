/**
 * Copyright @ 2008, 2010 Eric B. Decker
 * @author Eric B. Decker
 */
 
#include "sensors.h"

configuration DockCommC {
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
  components DockCommP;
  components new SerialAMSenderC(AM_MM_DATA);
  components new AMQueueImplP(MM_NUM_SENSORS), SerialActiveMessageC;
  
  MainC.SoftwareInit -> DockCommP;

  Send = AMQueueImplP;
  SendBusy = AMQueueImplP;
  Resource = DockCommP;
  ResourceRequested = DockCommP;
  AMPacket = SerialAMSenderC;
  Packet = SerialAMSenderC;
  SplitControl = SerialActiveMessageC;
  
  DockCommP.SubAMSend[AM_MM_DATA] -> SerialAMSenderC;
  AMQueueImplP.AMSend -> DockCommP.AMSend;
  AMQueueImplP.Packet -> SerialAMSenderC;
  AMQueueImplP.AMPacket -> SerialAMSenderC;
  
  components LedsC;
  DockCommP.Leds -> LedsC;
}
