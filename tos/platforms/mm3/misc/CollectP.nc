/*
 * mm3CollectP.nc - data collector (record managment) interface
 * between data collection and mass storage.
 * Copyright 2008, Eric B. Decker
 * Mam-Mark Project
 *
 */

#include "Collect.h"
#include "sd_blocks.h"

module CollectP {
  provides {
    interface Collect;
    interface Init;
    interface LogEvent;
  }
  uses {
    interface StreamStorage as SS;
    interface Panic;
    interface LocalTime<TMilli>;
  }
}

implementation {
  dc_control_t dcc;

  command error_t Init.init() {
    dcc.majik_a = DC_MAJIK_A;
    dcc.handle = NULL;
    dcc.cur_buf = NULL;
    dcc.cur_ptr = NULL;
    dcc.remaining = 0;
    dcc.chksum  = 0;
    dcc.seq = 0;
    dcc.majik_b = DC_MAJIK_B;
    return SUCCESS;
  }

  command void Collect.collect(uint8_t *data, uint16_t dlen) {
    uint16_t num_copied, i;

    /*
     * data length should also be 1st two bytes.
     * followed by dtype.  Minimum length is 3.
     * network order is big endian.
     */
    num_copied = (data[0] << 8) + data[1];

    if (num_copied != dlen || data[2] >= DT_MAX || dlen < 3)
      call Panic.reboot(PANIC_SS, 1, dlen, num_copied, data[2], 0);
    if (dcc.majik_a != DC_MAJIK_A || dcc.majik_b != DC_MAJIK_B)
      call Panic.reboot(PANIC_SS, 2, dcc.majik_a, dcc.majik_b, 0, 0);
    if (dcc.remaining > DC_BLK_SIZE)
      call Panic.reboot(PANIC_SS, 3, dcc.remaining, 0, 0, 0);

    while (dlen > 0) {
      if (dcc.cur_buf == NULL) {
        /*
         * nobody home, try to go get one.
	 *
	 * get_free_buf_handle either works or panics.
         */
	dcc.handle = call SS.get_free_buf_handle();
        dcc.cur_ptr = dcc.cur_buf = call SS.buf_handle_to_buf(dcc.handle);
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
	call SS.buffer_full(dcc.handle);
	dcc.handle = NULL;
        dcc.cur_buf = NULL;
        dcc.cur_ptr = NULL;
      }
    }
  }


  command void LogEvent.logEvent(uint8_t ev, uint16_t arg) {
    uint8_t event_data[DT_HDR_SIZE_EVENT];
    dt_event_nt *ep;

    ep = (dt_event_nt *) event_data;
    ep->len = DT_HDR_SIZE_EVENT;
    ep->dtype = DT_EVENT;
    ep->stamp_mis = call LocalTime.get();
    ep->ev = ev;
    ep->arg = arg;
    call Collect.collect(event_data, DT_HDR_SIZE_EVENT);
  }

  event void SS.read_block_done(uint32_t blk, uint8_t *buf, error_t err) { }
}
