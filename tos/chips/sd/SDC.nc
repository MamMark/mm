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

  components HplMsp430Usart1C as UsartC;
  SDP.Usart -> UsartC;
}
