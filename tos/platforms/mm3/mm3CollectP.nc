/* -*- mode:c; indent-tabs-mode: nil; c-basic-offset: 2 -*-
 *
 * mm3CollectP.nc - data collector (record managment) interface
 * between data collection and mass storage.
 * Copyright 2008, Eric B. Decker
 * Mam-Mark Project
 *
 */

#include "mm3Collect.h"

module mm3CollectP {
  provides {
    interface mm3Collect as DC;
    interface Init;
  }
}

implementation {
  dc_control_t dcc;
  uint8_t buf[512];

  uint8_t *ms_get_buffer() {
    return buf;
  }


  command error_t Init.init() {
    dcc.majik_a = DC_MAJIK_A;
    dcc.cur_buf = NULL;
    dcc.cur_ptr = NULL;
    dcc.chksum  = 0;
    dcc.remaining = 0;
    dcc.seq = 0;
    dcc.majik_b = DC_MAJIK_B;
    return SUCCESS;
  }


#ifdef notdef
  void write_version_record(uint8_t major, uint8_t minor, uint8_t tweak) {
    uint8_t vdata[DT_HDR_SIZE_VERSION];
    dt_version_pt *vp;

    vp = (dt_version_pt *) &vdata;
    vp->len = DT_HDR_SIZE_VERSION;
    vp->dtype = DT_VERSION;
    vp->major = major;
    vp->minor = minor;
    vp->tweak = tweak;
    dc_collect((uint8_t *) vp, DT_HDR_SIZE_VERSION);
  }


  void write_restart_record(void) {
    uint8_t sync_data[DT_HDR_SIZE_SYNC];
    dt_sync_pt *wrp;

    wrp = (dt_sync_pt *) &sync_data;
    wrp->len = DT_HDR_SIZE_SYNC;
    wrp->dtype = DT_SYNC;
    wrp->fill = 0x00;
    time_get_cur_packed(&wrp->stamp);
    wrp->sync_majik = SYNC_RESTART_MAJIK;

    dc_collect((uint8_t *) wrp, DT_HDR_SIZE_SYNC);
  }
#endif


  command void DC.collect(uint8_t *data, uint16_t dlen) {
    uint16_t num_copied, i;

    /*
     * data length should also be 1st two bytes.
     * followed by dtype.  Minimum length is 3.
     */
    num_copied = (data[1] << 8) + data[0];

#ifdef notdef
    if (num_copied != dlen || data[2] >= DT_MAX || dlen < 3)
      panic(PANIC_MS, 30, dlen, num_copied, data[2], 0);
    if (dcc.majik_a != DC_MAJIK_A || dcc.majik_b != DC_MAJIK_B)
      panic(PANIC_MS, 31, dcc.majik_a, dcc.majik_b, 0, 0);
    if (dcc.remaining > DC_BLK_SIZE)
      panic(PANIC_MS, 36, dcc.remaining, 0, 0, 0);
#endif

    while (dlen > 0) {
      if (dcc.cur_buf == NULL) {
        /*
         * nobody home, try to go get one.
         */
        dcc.cur_ptr = dcc.cur_buf = ms_get_buffer();
        dcc.remaining = DC_BLK_SIZE;
        dcc.chksum = 0;
      }
      num_copied = ((dlen < dcc.remaining) ? dlen : dcc.remaining);
      for (i = 0; i < num_copied; i++) {
        dcc.chksum += *data;
        *dcc.cur_ptr = *data;
        dcc.cur_ptr++;
        data++;
      }
      dlen -= num_copied;
      dcc.remaining -= num_copied;
      if (dcc.remaining == 0) {
        dcc.chksum += (dcc.seq & 0xff);
        dcc.chksum += (dcc.seq >> 8);
        (*(uint16_t *) dcc.cur_ptr) = dcc.seq++;
        dcc.cur_ptr += 2;
        (*(uint16_t *) dcc.cur_ptr) = dcc.chksum;
        dcc.cur_buf = NULL;
        dcc.cur_ptr = NULL;
      }
    }
  }


#ifdef notdef

  uint8_t test_buf[600];

  void
    dc_test(void) {
    uint16_t i;

    for (i = 0; i < 599; i++)
      test_buf[i] = i;
    test_buf[2] = DT_TEST;
    for (i = 3; i < 25; i++) {
      test_buf[0] = i & 0xff;
      test_buf[1] = i >> 8;
      dc_collect(test_buf, i);
      if (dcc.remaining <50)
        debug_break();
    }
  }

#endif
}
