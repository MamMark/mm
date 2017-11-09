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
extern ow_control_block_t ow_control_block;

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
    vp->len     = sizeof(v) + sizeof(image_info_t);
    vp->dtype   = DT_VERSION;
    vp->base    = call OverWatch.getImageBase();
    call Collect.collect((void *) vp, sizeof(dt_version_t),
                         (void *) &image_info, sizeof(image_info_t));
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

    rp = &r;
    rp->len = sizeof(r) + sizeof(ow_control_block_t);
    rp->dtype = DT_REBOOT;
    rp->stamp_ms = call SyncTimer.getNow();
    rp->time_cycle = 0;                 /* for now only time_cycle 0 */
    rp->sync_majik = SYNC_MAJIK;
    rp->dt_h_revision = DT_H_REVISION;  /* which version of typed_data */
    call Collect.collect((void *) rp, sizeof(r),
                         (void *) &ow_control_block,
                         sizeof(ow_control_block_t));
    call OverWatch.clearReset();        /* clears owcb copies */
  }


  /*
   * Always write the reboot record first.
   */
  event void Boot.booted() {
    write_reboot_record();
    write_version_record();
    nop();                              /* BRK */
    signal Booted.booted();
  }


  event void SysBoot.booted() {
    call SyncTimer.startPeriodic(SYNC_PERIOD);
  }


  event void SyncTimer.fired() {
    write_sync_record();
  }
}
