/**
 * Copyright @ 2008 Eric B. Decker
 * @author Eric B. Decker
 */

configuration CollectC {
  provides {
    interface Collect;
    interface LogEvent;
  }
}

implementation {
  components MainC, CollectP;
  MainC.SoftwareInit -> CollectP;
  Collect = CollectP;
  LogEvent = CollectP;

  components SSWriteC;
  CollectP.SSW -> SSWriteC;

  components PanicC;
  CollectP.Panic -> PanicC;

  components LocalTimeMilliC;
  CollectP.LocalTime -> LocalTimeMilliC;
}
