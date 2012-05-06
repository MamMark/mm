configuration ThrowC {
}
implementation {
  components MainC, ThrowP;
  ThrowP -> MainC.Boot;

  components HplMsp430InterruptC as InterruptC, new Msp430InterruptC() as P14;

  // uses HplMsp430Interrupt -> provides HplMsp430Interrupt
  P14 -> InterruptC.Port14;  

  //uses GpioInterrupt ->  provides GpioInterrupt as Interrupt
  ThrowP.Port14 -> P14.Interrupt;
}
