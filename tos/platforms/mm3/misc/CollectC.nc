/**
 * Copyright @ 2008 Eric B. Decker
 * @author Eric B. Decker
 */

configuration CollectC {
  provides interface Collect;
}

implementation {
  components MainC, CollectP;
  MainC.SoftwareInit -> CollectP;
  Collect = CollectP;

  components StreamStorageC;
  CollectP.SS -> StreamStorageC;

  components PanicC;
  CollectP.Panic -> PanicC;
}
