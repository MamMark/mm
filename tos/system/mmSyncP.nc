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
    dt_version_t  v;
    dt_version_t *vp;

    vp = &v;
    vp->len     = sizeof(v);
    vp->dtype   = DT_VERSION;
    vp->ver_id  = image_info.ver_id;
    vp->hw_ver  = image_info.hw_ver;
    call Collect.collect((void *) vp, sizeof(dt_version_t), NULL, 0);
  }


  void write_sync_record() {
    dt_sync_t  s;
    dt_sync_t *sp;

    sp = &s;
    sp->len = sizeof(s);
    sp->dtype = DT_SYNC;
    sp->stamp_ms = call SyncTimer.getNow();
    sp->sync_majik = SYNC_MAJIK;
    call Collect.collect((void *) sp, sizeof(dt_sync_t), NULL, 0);
  }


  void write_reboot_record() {
    dt_reboot_t  r;
    dt_reboot_t *rp;

    rp = &r;
    rp->len = sizeof(r);
    rp->dtype = DT_REBOOT;
    rp->stamp_ms = call SyncTimer.getNow();
    rp->sync_majik = SYNC_MAJIK;
    rp->boot_count = call BootParams.getBootCount();
    call Collect.collect((void *) rp, sizeof(r), NULL, 0);
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
