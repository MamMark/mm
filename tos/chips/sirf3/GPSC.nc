/*
 * Copyright (c) 2010 Eric B. Decker
 * All rights reserved.
 *
 * Rewritten 2010, to avoid arbritration for the MM4, 2618.
 * Dedicated serial port.  uses port usciA0, uart mode.
 */
 
/**
 * @author Eric B. Decker (cire831@gmail.com)
 * @date May 27, 2008
 */

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

  components HplMsp430UsciA0C as UsciC;
  GPSP.Usci -> UsciC;

  components new Msp430Uart0C() as UartC;
  GPSP.UartStream -> UartC;
  GPSP.UsciResource -> UartC;
  GPSP.UartConfigure <- UartC;
  
  components PanicC;
  GPSP.Panic -> PanicC;

  components TraceC;
  GPSP.Trace -> TraceC;

  components CollectC;
  GPSP.LogEvent -> CollectC;
}
