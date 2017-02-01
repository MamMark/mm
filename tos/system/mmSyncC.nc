/*
 * Copyright (c) 2008, 2010, 2017, Eric B. Decker
 * All rights reserved.
 */

configuration mmSyncC {
  provides interface Boot as OutBoot;
  uses {
    interface Boot;
    interface Boot as SysBoot;
  }
}

implementation {
  components SystemBootC, mmSyncP;
  mmSyncP.SysBoot -> SystemBootC.Boot;

  OutBoot = mmSyncP;
  Boot = mmSyncP.Boot;
  SysBoot = mmSyncP.SysBoot;
  
  components PlatformC;
  mmSyncP.BootParams -> PlatformC;

  components new TimerMilliC() as SyncTimerC;
  mmSyncP.SyncTimer -> SyncTimerC;

  components CollectC;
  mmSyncP.Collect -> CollectC;
}
