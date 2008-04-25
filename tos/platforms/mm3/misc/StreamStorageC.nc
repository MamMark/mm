/**
 * Copyright @ 2008 Eric B. Decker
 * @author Eric B. Decker
 */

configuration StreamStorageC {
  provides {
    interface StreamStorage as SS;
    interface StdControl as SSControl;
  }
}

implementation {
  components StreamStorageP, MainC;
  SS = StreamStorageP;
  SSControl = StreamStorageP;
  MainC.SoftwareInit -> StreamStorageP;

  components SDC;
  StreamStorageP.SD -> SDC;

  components PanicC;
  StreamStorageP.Panic -> PanicC;

  components HplMM3AdcC;
  StreamStorageP.HW -> HplMM3AdcC;
}
