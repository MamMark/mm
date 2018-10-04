/*
 * Copyright (c) 2017, Eric B. Decker
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 * See COPYING in the top level directory of this source tree.
 *
 * Contact: Eric B. Decker <cire831@gmail.com>
 *
 * Handle an incoming SIRF binary byte stream assembling it into protocol
 * messages.  Assemble into GPSMsgs.  Processing of the incoming msgs will
 * be handled by upper layer processors.
 */

#include <panic.h>
#include <platform_panic.h>
#include <sirf_driver.h>

#ifndef PANIC_GPS
enum {
  __pcode_gps = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_GPS __pcode_gps
#endif

module SirfBinP {
  provides {
    interface GPSProto;
  }
  uses {
    interface GPSBuffer;
    interface Collect;
    interface Panic;
  }
}

implementation {

  /*
   * GPS Proto Collector states.  Where in the message is the state machine.  Used
   * when collecting messages.
   */
  typedef enum {
    SBS_START = 0,                  /* A0 */
    SBS_START_2,                    /* A2 */
    SBS_LEN,                        /* len msb */
    SBS_LEN_2,                      /* len lsb */
    SBS_PAYLOAD,
    SBS_CHK,                        /* chk msb */
    SBS_CHK_2,                      /* chk lsb */
    SBS_END,                        /* B0 */
    SBS_END_2,                      /* B3 */
  } sbs_t;                          /* sirfbin_state type */


  norace sbs_t     sirfbin_state;       // message collection state
  norace sbs_t     sirfbin_state_prev;  // debugging
  norace uint16_t  sirfbin_left;        // payload bytes left
  norace uint16_t  sirfbin_chksum;      // running chksum of payload
  norace uint8_t  *sirfbin_ptr;         // where to stash incoming bytes
  norace uint8_t  *sirfbin_ptr_prev;    // for debugging
  norace uint8_t  *sb_low, *sb_high;    // paranoid limits
  norace uint8_t  *sb_start;            // paranoid where cur msg starts


  /*
   * Instrumentation, Stats
   */
  norace dt_gps_proto_stats_t  sirfbin_stats;
  norace sirfbin_other_stats_t sirfbin_other_stats;

  /*
   * sirfbin_reset: reset sirfbin proto state
   *
   * Does not tell the outside world that anything
   * has happened via GPSProto.msgAbort.
   */
  inline void sirfbin_reset() {
    sirfbin_stats.resets++;
    sirfbin_state_prev = sirfbin_state;
    sirfbin_state = SBS_START;
    if (sirfbin_ptr) {
      sirfbin_ptr_prev = sirfbin_ptr;
      sirfbin_ptr = NULL;
      call GPSBuffer.msg_abort();
    }
  }


  /*
   * sirfbin_restart_abort: reset and tell interested parties (typically
   * the driver layer).
   *
   * First reset the sirfbin protocol state and tell interested parties
   * that the current message is being aborted.
   *
   * Restart_Aborts get generated internally from the Proto
   * engine.
   */
  inline void sirfbin_restart_abort(uint16_t where) {
    atomic {
      sirfbin_reset();
      signal GPSProto.protoAbort(where);
    }
  }


  command void GPSProto.rx_timeout() {
    atomic {
      sirfbin_stats.rx_timeouts++;
      sirfbin_reset();
    }
  }


  /*
   * An rx_error occurred.  The underlying comm h/w isn't happy
   * Also throw a GPSProto.msgAbort to do reasonable things with
   * the underlying driver state machine.
   */
  async command void GPSProto.rx_error(uint16_t gps_errors) {
    atomic {
      sirfbin_stats.rx_errors++;
      if (gps_errors & GPSPROTO_RXERR_FRAMING)
        sirfbin_stats.rx_framing++;
      if (gps_errors & GPSPROTO_RXERR_OVERRUN)
        sirfbin_stats.rx_overrun++;
      if (gps_errors & GPSPROTO_RXERR_PARITY)
        sirfbin_stats.rx_parity++;
      sirfbin_reset();
    }
  }


  async command void GPSProto.resetStats() {
      sirfbin_stats.starts           = 0;
      sirfbin_stats.complete         = 0;
      sirfbin_stats.ignored          = 0;
      sirfbin_stats.resets           = 0;
      sirfbin_stats.too_small        = 0;
      sirfbin_stats.too_big          = 0;
      sirfbin_stats.chksum_fail      = 0;
      sirfbin_stats.rx_timeouts      = 0;
      sirfbin_stats.rx_errors        = 0;
      sirfbin_stats.rx_framing       = 0;
      sirfbin_stats.rx_overrun       = 0;
      sirfbin_stats.rx_parity        = 0;
      sirfbin_stats.proto_start_fail = 0;
      sirfbin_stats.proto_end_fail   = 0;
  }


  command void GPSProto.logStats() {
    dt_header_t hdr;
    dt_header_t *hp;

    hp = &hdr;
    hp->len   = sizeof(hdr) + sizeof(sirfbin_stats);
    hp->dtype = DT_GPS_PROTO_STATS;
    atomic {
      call Collect.collect((void *) &hdr, sizeof(hdr),
                 (void *) &sirfbin_stats, sizeof(sirfbin_stats));
      call GPSProto.resetStats();
    }
  }


  async command void GPSProto.byteAvail(uint8_t byte) {
    uint16_t chksum;

    switch(sirfbin_state) {
      case SBS_START:
	if (byte != SIRFBIN_A0) {
          sirfbin_stats.ignored++;
	  return;
        }
        sirfbin_state_prev = sirfbin_state;
	sirfbin_state = SBS_START_2;
	return;

      case SBS_START_2:
	if (byte == SIRFBIN_A0) {               // got start again.  stay, good dog
          sirfbin_stats.ignored++;              // previous byte got ignored
	  return;
        }
	if (byte != SIRFBIN_A2) {		// not what we want.  restart
          sirfbin_stats.proto_start_fail++;     // weird, count it
	  sirfbin_restart_abort(1);
	  return;
	}
        sirfbin_state_prev = sirfbin_state;
	sirfbin_state = SBS_LEN;
        sirfbin_stats.starts++;
	return;

      case SBS_LEN:
	sirfbin_left = byte << 8;		// data fields are big endian
        sirfbin_state_prev = sirfbin_state;
	sirfbin_state = SBS_LEN_2;
	return;

      case SBS_LEN_2:
	sirfbin_left |= byte;
        if (sirfbin_left <  SIRFBIN_MIN_MSG) {
          sirfbin_stats.too_small++;
          sirfbin_restart_abort(2);
          return;
        }
	if (sirfbin_left >= SIRFBIN_MAX_MSG) {
          if (sirfbin_left > sirfbin_other_stats.largest_seen)
            /*
             * largest_seen is the largest we have ever seen
             * including those that are bigger then our
             * max.
             */
            sirfbin_other_stats.largest_seen = sirfbin_left;
	  sirfbin_stats.too_big++;
	  sirfbin_restart_abort(2);
	  return;
	}
        if (sirfbin_left > sirfbin_other_stats.max_seen)
          sirfbin_other_stats.max_seen = sirfbin_left;
        sirfbin_ptr_prev = sirfbin_ptr;
        sirfbin_ptr = call GPSBuffer.msg_start(sirfbin_left + SIRFBIN_OVERHEAD);
        if (!sirfbin_ptr) {
          sirfbin_other_stats.no_buffer++;
          sirfbin_restart_abort(3);
          return;
        }
        sb_start = sirfbin_ptr;
        signal GPSProto.msgStart(sirfbin_left + SIRFBIN_OVERHEAD);
        sirfbin_state_prev = sirfbin_state;
	sirfbin_state = SBS_PAYLOAD;
        sirfbin_chksum = 0;
        *sirfbin_ptr++ = SIRFBIN_A0;
        *sirfbin_ptr++ = SIRFBIN_A2;
        *sirfbin_ptr++ = (sirfbin_left >> 8) & 0xff;
        *sirfbin_ptr++ = sirfbin_left & 0xff;
        sb_low         = sirfbin_ptr;
        sb_high        = sirfbin_ptr + sirfbin_left - 1;
	return;

      case SBS_PAYLOAD:
        if (sirfbin_ptr < sb_low || sirfbin_ptr > sb_high)
          call Panic.panic(PANIC_GPS, 136, (parg_t) sirfbin_ptr,
                           (parg_t) sb_low, (parg_t) sb_high, 0);

        /* look for SOP corruption, we've seen the 1st 4 wacked */
        if ((sb_start[0] != SIRFBIN_A0) || (sb_start[1] != SIRFBIN_A2))
          call Panic.panic(PANIC_GPS, 137, (parg_t) sirfbin_ptr,
                           (parg_t) sb_start, sb_start[0], sb_start[1]);
        *sirfbin_ptr++ = byte;
	sirfbin_chksum += byte;
	sirfbin_left--;
	if (sirfbin_left == 0) {
          sirfbin_state_prev = sirfbin_state;
	  sirfbin_state = SBS_CHK;
          sb_low  = sb_high + 1;
          sb_high = sb_low;
        }
	return;

      case SBS_CHK:
        if (sirfbin_ptr < sb_low || sirfbin_ptr > sb_high)
          call Panic.panic(PANIC_GPS, 136, (parg_t) sirfbin_ptr,
                           (parg_t) sb_low, (parg_t) sb_high, 0);
        *sirfbin_ptr++ = byte;
        sirfbin_state_prev = sirfbin_state;
	sirfbin_state = SBS_CHK_2;
        sb_low  = sb_high + 1;
        sb_high = sb_low;
	return;

      case SBS_CHK_2:
        if (sirfbin_ptr < sb_low || sirfbin_ptr > sb_high)
          call Panic.panic(PANIC_GPS, 136, (parg_t) sirfbin_ptr,
                           (parg_t) sb_low, (parg_t) sb_high, 0);
        *sirfbin_ptr++ = byte;
	chksum = sirfbin_ptr[-2] << 8 | byte;
	if (chksum != sirfbin_chksum) {
	  sirfbin_stats.chksum_fail++;
	  sirfbin_restart_abort(4);
	  return;
	}
        sirfbin_state_prev = sirfbin_state;
	sirfbin_state = SBS_END;
        sb_low  = sb_high + 1;
        sb_high = sb_low;
	return;

      case SBS_END:
        if (sirfbin_ptr < sb_low || sirfbin_ptr > sb_high)
          call Panic.panic(PANIC_GPS, 136, (parg_t) sirfbin_ptr,
                           (parg_t) sb_low, (parg_t) sb_high, 0);
        *sirfbin_ptr++ = byte;
	if (byte != SIRFBIN_B0) {
	  sirfbin_stats.proto_end_fail++;
	  sirfbin_restart_abort(5);
	  return;
	}
        sirfbin_state_prev = sirfbin_state;
	sirfbin_state = SBS_END_2;
        sb_low  = sb_high + 1;
        sb_high = sb_low;
	return;

      case SBS_END_2:
        if (sirfbin_ptr < sb_low || sirfbin_ptr > sb_high)
          call Panic.panic(PANIC_GPS, 136, (parg_t) sirfbin_ptr,
                           (parg_t) sb_low, (parg_t) sb_high, 0);
        *sirfbin_ptr++ = byte;
	if (byte != SIRFBIN_B3) {
	  sirfbin_stats.proto_end_fail++;
	  sirfbin_restart_abort(6);
	  return;
	}
        sirfbin_ptr_prev = sirfbin_ptr;
        sirfbin_ptr = NULL;
        sirfbin_state_prev = sirfbin_state;
        sirfbin_state = SBS_START;
        sirfbin_stats.complete++;
        signal GPSProto.msgEnd();
        call GPSBuffer.msg_complete();
	return;

      default:
	call Panic.warn(PANIC_GPS, 135, sirfbin_state, 0, 0, 0);
	sirfbin_restart_abort(7);
	return;
    }
  }

        event void Collect.collectBooted() { }
        event void Collect.resyncDone(error_t err, uint32_t offset) { }
  async event void Panic.hook() { }
}
