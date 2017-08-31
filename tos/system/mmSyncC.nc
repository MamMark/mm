/*
 * Copyright (c) 2008, 2010, 2017, Eric B. Decker
 * All rights reserved.
 */

configuration mmSyncC {
  provides interface Boot as Booted;    /* out boot */
  uses     interface Boot;              /* in  boot */
}
implementation {
  components SystemBootC, mmSyncP;
  mmSyncP.SysBoot -> SystemBootC.Boot;

  Booted = mmSyncP;
  Boot   = mmSyncP.Boot;

  components PlatformC;
  mmSyncP.BootParams -> PlatformC;

  components new TimerMilliC() as SyncTimerC;
  mmSyncP.SyncTimer -> SyncTimerC;

  components CollectC;
  mmSyncP.Collect -> CollectC;
}
