/**
 *
 * Copyright 2008, 2010 (c) Eric B. Decker
 * All rights reserved.
 *
 * @author Eric B. Decker
 */

configuration PlatformSerialC {
  provides interface StdControl;
  provides interface UartStream;
  provides interface UartByte;
}

implementation {
  components new Msp430Uart1C() as UartC;
  UartStream = UartC;
  UartByte = UartC;

  components DockSerialP;
  StdControl = DockSerialP;
  DockSerialP.Msp430UartConfigure <- UartC.Msp430UartConfigure;
  DockSerialP.Resource -> UartC;
}
