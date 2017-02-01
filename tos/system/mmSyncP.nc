/*
 * Copyright (c) 2008, 2010, 2014, 2017: Eric B. Decker
 * All rights reserved.
 */

/*
 * 1 min * 60 sec/min * 1024 ticks/sec
 * Tmilli is binary
 */
#define SYNC_PERIOD (1UL * 60 * 1024)

module mmSyncP {
  provides interface Boot as OutBoot;
  uses {
    interface Boot;
    interface Boot as SysBoot;
    interface BootParams;
    interface Timer<TMilli> as SyncTimer;
    interface Collect;
  }
}

implementation {

  void write_version_record() {
    uint8_t vdata[DT_HDR_SIZE_VERSION];
    dt_version_nt *vp;

    vp = (dt_version_nt *) &vdata;
    vp->len     = DT_HDR_SIZE_VERSION;
    vp->dtype   = DT_VERSION;
    vp->major   = call BootParams.getMajor();
    vp->minor   = call BootParams.getMinor();
    vp->build   = call BootParams.getBuild();
    call Collect.collect(vdata, DT_HDR_SIZE_VERSION);
  }


  void write_sync_record() {
    uint8_t sync_data[DT_HDR_SIZE_SYNC];
    dt_sync_nt *sdp;

    sdp = (dt_sync_nt *) &sync_data;
    sdp->len = DT_HDR_SIZE_SYNC;
    sdp->dtype = DT_SYNC;
    sdp->stamp_ms = call SyncTimer.getNow();
    sdp->sync_majik = SYNC_MAJIK;
    call Collect.collect(sync_data, DT_HDR_SIZE_SYNC);
  }


  void write_reboot_record() {
    uint8_t reboot_data[DT_HDR_SIZE_REBOOT];
    dt_reboot_nt *rbdp;

    rbdp = (dt_reboot_nt *) &reboot_data;
    rbdp->len = DT_HDR_SIZE_REBOOT;
    rbdp->dtype = DT_REBOOT;
    rbdp->stamp_ms = call SyncTimer.getNow();
    rbdp->sync_majik = SYNC_MAJIK;
    rbdp->boot_count = call BootParams.getBootCount();
    call Collect.collect(reboot_data, DT_HDR_SIZE_REBOOT);
  }


  /*
   * Always write the reboot record first.
   */
  event void Boot.booted() {
    write_reboot_record();
    write_version_record();
    nop();
    signal OutBoot.booted();
  }


  event void SysBoot.booted() {
    call SyncTimer.startPeriodic(SYNC_PERIOD);
  }


  event void SyncTimer.fired() {
    write_sync_record();
  }
}
