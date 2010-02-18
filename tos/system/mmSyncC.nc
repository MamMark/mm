/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

configuration mm3SyncC {
  provides {
    interface Boot as OutBoot;
  }
  uses {
    interface Boot;
    interface Boot as SysBoot;
  }
}

implementation {
  components SystemBootC, mm3SyncP;
//  SystemBootC.SoftwareInit -> mm3SyncP;
  mm3SyncP.SysBoot -> SystemBootC.Boot;

  OutBoot = mm3SyncP;
  Boot = mm3SyncP.Boot;
  SysBoot = mm3SyncP.SysBoot;
  
  components new TimerMilliC() as SyncTimerC;
  mm3SyncP.SyncTimer -> SyncTimerC;

  components mm3CommDataC;
  mm3SyncP.mm3CommData -> mm3CommDataC.mm3CommData[SNS_ID_NONE];

  components CollectC;
  mm3SyncP.Collect -> CollectC;
}
