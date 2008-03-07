
configuration PlatformSerialC {
  
  provides interface StdControl;
  provides interface UartStream;
  provides interface UartByte;
  
}

implementation {
  
  components new Msp430Uart1C() as UartC;
  UartStream = UartC;  
  UartByte = UartC;
  
  components Mm3SerialP;
  StdControl = Mm3SerialP;
  Mm3SerialP.Msp430UartConfigure <- UartC.Msp430UartConfigure;
  Mm3SerialP.Resource -> UartC.Resource;
  
}
