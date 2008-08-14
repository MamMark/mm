/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#include "regime.h"
#include "panic.h"

/*
 * 1 min * 60 sec/min * 1024 ticks/sec  (binary millisecs, mis)
 */
#define SYNC_PERIOD (1UL * 60 * 1024)

#ifdef notdef
#define NUM_RES 16
uint16_t res[NUM_RES];
#endif

noinit uint8_t use_regime;
//uint8_t use_regime;

//noinit uint16_t gps_nxt;
//uint8_t buff[2048];

module mm3C {
  provides interface Init;
  uses {
    interface Regime;
    interface Leds;
    interface Boot;
    interface Panic;
    interface Timer<TMilli> as SyncTimer;
    interface Collect;
    interface mm3CommData;
    interface StreamStorageFull;

    interface HplMM3Adc as HW;
    interface Adc;

#ifdef TEST_GPS
    interface StdControl as GPSControl;
#endif
  }
}

implementation {

  command error_t Init.init() {
//    call Panic.brk();
    return SUCCESS;
  }

  void write_version_record(uint8_t major, uint8_t minor, uint8_t tweak) {
    uint8_t vdata[DT_HDR_SIZE_VERSION];
    dt_version_nt *vp;

    vp = (dt_version_nt *) &vdata;
    vp->len = DT_HDR_SIZE_VERSION;
    vp->dtype = DT_VERSION;
    vp->major = major;
    vp->minor = minor;
    vp->tweak = tweak;
    call mm3CommData.send_data(vdata, DT_HDR_SIZE_VERSION);
    call Collect.collect(vdata, DT_HDR_SIZE_VERSION);
  }


  void write_sync_record(bool sync) {
    uint8_t sync_data[DT_HDR_SIZE_SYNC];
    dt_sync_nt *sdp;

    sdp = (dt_sync_nt *) &sync_data;
    sdp->len = DT_HDR_SIZE_SYNC;
    if (sync)
      sdp->dtype = DT_SYNC;
    else
      sdp->dtype = DT_SYNC_RESTART;
    sdp->stamp_mis = call SyncTimer.getNow();
    sdp->sync_majik = SYNC_MAJIK;
    call mm3CommData.send_data(sync_data, DT_HDR_SIZE_SYNC);
    call Collect.collect(sync_data, DT_HDR_SIZE_SYNC);
  }


  event void Boot.booted() {

#ifdef TEST_GPS
    call GPSControl.start();
    // call GPSControl.stop();
    //    return;
#endif

    call SyncTimer.startPeriodic(SYNC_PERIOD);

    /*
     * Tell folks what we are running.
     */
    write_version_record(1, 1, 0);
    write_sync_record(FALSE);

    /*
     * set the initial regime.  This will also
     * signal all the sensors and start them off.
     */
//    call Regime.setRegime(SNS_DEFAULT_REGIME);
    if (use_regime > SNS_MAX_REGIME)
      use_regime = SNS_DEFAULT_REGIME;
    call Regime.setRegime(use_regime);

//    call Leds.led0Off();
//    call Leds.led1Off();
//    call Leds.led2Off();

#ifdef notdef
    call HW.vdiff_on();
    call HW.vref_on();
    call HW.accel_on();
    call HW.set_smux(SMUX_ACCEL_X);
    uwait(1000);
    while(1) {
      uint16_t i;

      for (i = 0; i < NUM_RES; i++)
	res[i] = call Adc.readAdc();
      nop();
    }
#endif

  }

  event void SyncTimer.fired() {
    write_sync_record(TRUE);
  }

  event void mm3CommData.send_data_done(error_t rtn) { }

  event void StreamStorageFull.dblk_stream_full () {
    call Regime.setRegime(SNS_ALL_OFF_REGIME);
  }

  event void Adc.configured() {
    call Panic.panic(PANIC_MISC, 1, 0, 0, 0, 0);
  }

  event void Regime.regimeChange() {} // do nothing.  that's okay.
}
