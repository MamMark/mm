/*
 * Copyright (c) 2008, 2010, Eric B. Decker
 * All rights reserved.
 */

#include "platform_version.h"


//#define SYNC_TEST


/*
 * 1 min * 60 sec/min * 1024 ticks/sec  (binary millisecs, mis)
 */
#define SYNC_PERIOD (1UL * 60 * 1024)

typedef enum {
  SYNC_BOOT_NORMAL = 0,
  SYNC_BOOT_1      = 1,
  SYNC_BOOT_2      = 2,
#ifdef SYNC_TEST
  SYNC_SEND_TEST   = 3,
#endif
} sync_boot_state_t;


module mmSyncP {
  provides {
    interface Boot as OutBoot;
    interface BootParams;
  }
  uses {
    interface Boot;
    interface Boot as SysBoot;
    interface Timer<TMilli> as SyncTimer;
    interface Collect;
    interface DTSender;
  }
}

implementation {
  sync_boot_state_t boot_state;

#ifdef SYNC_TEST
  void write_test() {
    uint8_t vdata[DT_HDR_SIZE_VERSION];
    uint8_t i;

    for (i = 0; i < DT_HDR_SIZE_VERSION; i++)
      vdata[i] = i;
    call DTSender.send(vdata, DT_HDR_SIZE_VERSION);
  }
#endif


  /*
   * Need to rework usage of DTSender.send so if it fails
   * it still generates send_data_done.
   *
   * Otherwise, we hang in the boot sequence.  How does this work
   * when comm is down?
   */
  void write_version_record() {
    uint8_t vdata[DT_HDR_SIZE_VERSION];
    dt_version_nt *vp;

    vp = (dt_version_nt *) &vdata;
    vp->len     = DT_HDR_SIZE_VERSION;
    vp->dtype   = DT_VERSION;
    vp->major   = BootParams.getMajor();
    vp->minor   = BootParams.getMinor();
    vp->build   = BootParams.getBuild();
    call Collect.collect(vdata, DT_HDR_SIZE_VERSION);
    call DTSender.send(vdata, DT_HDR_SIZE_VERSION);
  }


  void write_sync_record() {
    uint8_t sync_data[DT_HDR_SIZE_SYNC];
    dt_sync_nt *sdp;

    sdp = (dt_sync_nt *) &sync_data;
    sdp->len = DT_HDR_SIZE_SYNC;
    sdp->dtype = DT_SYNC;
    sdp->stamp_mis = call SyncTimer.getNow();
    sdp->sync_majik = SYNC_MAJIK;
    call Collect.collect(sync_data, DT_HDR_SIZE_SYNC);
    call DTSender.send(sync_data, DT_HDR_SIZE_SYNC);
  }


  void write_resync_record() {
    uint8_t resync_data[DT_HDR_SIZE_RESYNC];
    dt_resync_nt *sdp;

    sdp = (dt_sync_nt *) &resync_data;
    sdp->len = DT_HDR_SIZE_RESYNC;
    sdp->dtype = DT_SYNC_RESTART;
    sdp->stamp_mis = call SyncTimer.getNow();
    sdp->sync_majik = SYNC_MAJIK;
    sdp->boot_count = BootParams.getBootCount();
    call Collect.collect(sync_data, DT_HDR_SIZE_RESYNC);
    call DTSender.send(sync_data, DT_HDR_SIZE_RESYNC);
  }


  /*
   * Always write the resync record first.
   */
  event void Boot.booted() {
#ifdef SYNC_TEST
    boot_state = SYNC_SEND_TEST;
    write_test();
#else
    boot_state = SYNC_BOOT_1;
    write_resync_record();
#endif
  }


  /*
   * Uses DTSender port SNS_ID_NONE (shared with others) so need
   * to be prepared to handle send_data_done completion events that
   * we didn't kick off.
   */
  event void DTSender.sendDone(error_t err) {
    switch (boot_state) {
      default:
	break;

#ifdef SYNC_TEST
      case SYNC_SEND_TEST:
	boot_state = SYNC_BOOT_1;
	write_resync_record();
	break;
#endif

      case SYNC_BOOT_1:
	boot_state = SYNC_BOOT_2;
	write_version_record();
	break;

      case SYNC_BOOT_2:
	boot_state = SYNC_BOOT_NORMAL;
	signal OutBoot.booted();
	break;
    }
  }


  event void SysBoot.booted() {
    call SyncTimer.startPeriodic(SYNC_PERIOD);
  }


  event void SyncTimer.fired() {
    write_sync_record();
  }
}
