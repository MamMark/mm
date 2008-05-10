/**
 *
 * Copyright 2008 (c) Eric B. Decker
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
  
  components mm3SerialP;
  StdControl = mm3SerialP;
  mm3SerialP.Msp430UartConfigure <- UartC.Msp430UartConfigure;
  
  components mm3SerialCommC;
  mm3SerialCommC.Resource -> UartC.Resource;
}
