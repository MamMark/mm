/*
 * Copyright (c) 2008, 2010, 2014, 2017: Eric B. Decker
 * All rights reserved.
 */

#include <overwatch.h>
#include <image_info.h>

/*
 * 1 min * 60 sec/min * 1024 ticks/sec
 * Tmilli is binary
 */
#define SYNC_PERIOD (1UL * 60 * 1024)

extern image_info_t image_info;

module mmSyncP {
  provides interface Boot as Booted;    /* out boot */
  uses {
    interface Boot;                     /* in boot in sequence */
    interface Boot as SysBoot;          /* use at end of System Boot initilization */
    interface Timer<TMilli> as SyncTimer;
    interface Collect;
    interface OverWatch;
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
    sp->time_cycle = 0;                 /* for now only time_cycle 0 */
    call Collect.collect((void *) sp, sizeof(dt_sync_t), NULL, 0);
  }


  void write_reboot_record() {
    dt_reboot_t  r;
    dt_reboot_t *rp;
    ow_control_block_t *owcp;

    rp = &r;
    owcp = call OverWatch.getControlBlock();
    rp->len = sizeof(r);
    rp->dtype = DT_REBOOT;
    rp->stamp_ms = call SyncTimer.getNow();
    rp->sync_majik = SYNC_MAJIK;
    rp->time_cycle = 0;                 /* for now only time_cycle 0 */

    rp->hard_reset = owcp->hard_reset;
    rp->boot_count = owcp->reboot_count;

    rp->elapsed_upper = owcp->elapsed_upper;
    rp->elapsed_lower = owcp->elapsed_lower;

    rp->strange = owcp->strange;
    rp->vec_chk_fail = owcp->vec_chk_fail;
    rp->image_chk_fail = owcp->image_chk_fail;
    rp->reboot_reason = owcp->reboot_reason;

    call OverWatch.clearReset();
    call Collect.collect((void *) rp, sizeof(r), NULL, 0);
  }


  /*
   * Always write the reboot record first.
   */
  event void Boot.booted() {
    write_reboot_record();
    write_version_record();
    nop();
    signal Booted.booted();
  }


  event void SysBoot.booted() {
    call SyncTimer.startPeriodic(SYNC_PERIOD);
  }


  event void SyncTimer.fired() {
    write_sync_record();
  }
}
