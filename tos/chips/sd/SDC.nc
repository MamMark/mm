/**
 * Copyright @ 2008 Eric B. Decker
 * @author Eric B. Decker
 */

configuration SDC {
  provides interface SD;
}

implementation {
  components SDP, MainC;
  SD = SDP;
  MainC.SoftwareInit -> SDP;

  components PanicC;
  SDP.Panic -> PanicC;

  components StreamStorageC;
  SDP.BlockingSpiPacket -> StreamStorageC;

#if defined(PLATFORM_MM3)
  components HplMsp430Usart1C as UsartC;
  SDP.Umod -> UsartC;
#elif defined(PLATFORM_MM4)
  components HplMsp430UsciB0C as UsciC;
  SDP.Umod -> UsciC;
  SDP.UsciInterrupts -> UsciC;
#endif
}
