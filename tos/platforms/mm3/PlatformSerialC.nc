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
  
  components mmSerialP;
  StdControl = mmSerialP;
  mmSerialP.Msp430UartConfigure <- UartC.Msp430UartConfigure;
  
  components mmSerialCommC;
  mmSerialCommC.Resource -> UartC.Resource;
  mmSerialCommC.ResourceRequested -> UartC.ResourceRequested;
}
