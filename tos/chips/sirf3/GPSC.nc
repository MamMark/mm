/*
 * Copyright (c) 2010 Eric B. Decker
 * All rights reserved.
 *
 * Rewritten 2010, to avoid arbritration for the MM4, 2618.
 * Dedicated serial port.
 */
 
/**
 * @author Eric B. Decker (cire831@gmail.com)
 * @date May 27, 2008
 */

#include "serial_demux.h"

configuration GPSC {
  provides {
    interface StdControl as GPSControl;
    interface Boot as GPSBoot;
  }
  uses interface Boot;
}

implementation {
  components MainC, GPSP;
  MainC.SoftwareInit -> GPSP;
  GPSControl = GPSP;
  GPSBoot = GPSP;
  Boot = GPSP.Boot;

  components GPSMsgC;
  GPSP.GPSMsg -> GPSMsgC;
  GPSP.GPSMsgControl -> GPSMsgC;

  components Hpl_MM_hwC;
  GPSP.HW -> Hpl_MM_hwC;

  components LocalTimeMilliC;
  GPSP.LocalTime -> LocalTimeMilliC;

  components new TimerMilliC() as GPSTimer;
  GPSP.GPSTimer -> GPSTimer;

  components HplMsp430Usart1C;
  GPSP.Usart -> HplMsp430Usart1C;

  components PanicC;
  GPSP.Panic -> PanicC;

  components TraceC;
  GPSP.Trace -> TraceC;

  components CollectC;
  GPSP.LogEvent -> CollectC;

  components SerialDemuxC;
  GPSP.SerialDefOwner      -> SerialDemuxC.SerialDefOwnerClient[SERIAL_OWNER_GPS];
  GPSP.SerialDemuxResource -> SerialDemuxC.SerialDemuxResource[SERIAL_OWNER_GPS];
  GPSP.UartStream          -> SerialDemuxC.SerialClientUartStream[SERIAL_OWNER_GPS];
  GPSP.MuxControl          -> SerialDemuxC;

//  components new Msp430Uart1C() as UartC;
//  GPSP.UartStream -> UartC;  
//  GPSP.UartByte -> UartC;

}
