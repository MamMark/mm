/**
 * Copyright @ 2008 Eric B. Decker
 * @author Eric B. Decker
 */

configuration StreamStorageC {
  provides {
    interface StreamStorage as SS;
    interface SplitControl as SSControl;
}

implementation {
  components StreamStorageP, MainC;
  SS = StreamStorageP;
  SSControl = StreamStorageP;
  MainC.SoftwareInit -> StreamStorageP;

  components PanicC;
  StreamStorageP.Panic -> PanicC;

  components HplMsp430Usart1C as UsartC;
  StreamStorageP.Usart -> UsartC;
}
