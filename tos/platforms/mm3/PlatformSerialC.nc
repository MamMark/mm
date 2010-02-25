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

  components mm3DockSerialP;
  StdControl = mm3DockSerialP;
  mm3DockSerialP.Msp430UartConfigure <- UartC.Msp430UartConfigure;

  components DockCommArbiterC;
  DockCommArbiterC.Resource -> UartC.Resource;
  DockCommArbiterC.ResourceRequested -> UartC.ResourceRequested;
}
