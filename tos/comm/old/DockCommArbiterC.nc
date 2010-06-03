/**
 * Copyright @ 2008, 2010 Eric B. Decker
 * @author Eric B. Decker
 */
 
#include "sensors.h"
#include "am_types.h"

configuration DockCommArbiterC {
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
  components DockCommArbiterP;
  components new SerialAMSenderC(AM_MM_DT);
  components new AMQueueImplP(MM_NUM_SENSORS), SerialActiveMessageC;
  
  Send = AMQueueImplP;
  SendBusy = AMQueueImplP;
  Resource = DockCommArbiterP;
  ResourceRequested = DockCommArbiterP;
  AMPacket = SerialAMSenderC;
  Packet = SerialAMSenderC;
  SplitControl = SerialActiveMessageC;
  
  DockCommArbiterP.SubAMSend[AM_MM_DT] -> SerialAMSenderC;
  AMQueueImplP.AMSend -> DockCommArbiterP.AMSend;
  AMQueueImplP.Packet -> SerialAMSenderC;
  AMQueueImplP.AMPacket -> SerialAMSenderC;
  
  components LedsC;
  DockCommArbiterP.Leds -> LedsC;
}
