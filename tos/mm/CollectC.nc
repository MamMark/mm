/**
 * Copyright @ 2008,2017 Eric B. Decker
 * @author Eric B. Decker
 */

configuration CollectC {
  provides {
    interface Boot as Booted;           /* out boot */
    interface Collect;
    interface CollectEvent;
  }
  uses     interface Boot;              /* in  boot */
}

implementation {

  components MainC, SystemBootC, CollectP;
  MainC.SoftwareInit -> CollectP;
  CollectP.SysBoot   -> SystemBootC.Boot;

  Booted       = CollectP;
  Collect      = CollectP;
  CollectEvent = CollectP;
  Boot         = CollectP.Boot;

  components new TimerMilliC() as SyncTimerC;
  CollectP.SyncTimer -> SyncTimerC;

  components OverWatchC;
  CollectP.OverWatch -> OverWatchC;

  components DblkManagerC;
  CollectP.DblkManager -> DblkManagerC;

  components SSWriteC;
  CollectP.SSW -> SSWriteC;

  components PanicC;
  CollectP.Panic -> PanicC;

  components LocalTimeMilliC;
  CollectP.LocalTime -> LocalTimeMilliC;

  components PlatformC;
  CollectP.SysReboot -> PlatformC;
}
