/*
 * Copyright (c) 2020, Eric B. Decker
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
 * Handle an incoming UBX binary byte stream assembling it into protocol
 * messages.  Processing of the incoming msgs will be handled by upper
 * layer processors.
 */

#include <panic.h>
#include <platform_panic.h>
#include <ublox_driver.h>

#ifndef PANIC_GPS
enum {
  __pcode_gps = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_GPS __pcode_gps
#endif

module ubxProtoP {
  provides {
    interface GPSProto;
  }
  uses {
    interface MsgBuf;
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
    UBXS_SYNC1 = 0,                     /* 0xB5, 'u' */
    UBXS_SYNC2,                         /* 0x62, 'b' */
    UBXS_CLASS,
    UBXS_ID,
    UBXS_LEN_LSB,                       /* len lsb */
    UBXS_LEN_MSB,                       /* len msb */
    UBXS_PAYLOAD,
    UBXS_CHK_A,                         /* chkA byte */
    UBXS_CHK_B,                         /* chkB byte */
  } ubxs_t;                             /* ubx_state type */


  norace ubxs_t    ubx_state;           // message collection state
  norace ubxs_t    ubx_state_prev;      // debugging
  norace uint8_t   ubx_class;           // message class
  norace uint8_t   ubx_id;              // message id
  norace uint16_t  ubx_left;            // payload bytes left
  norace uint8_t   ubx_chk_a;           // fletcher checksum
  norace uint8_t   ubx_chk_b;           // fletcher checksum
  norace uint8_t  *ubx_ptr;             // where to stash incoming bytes
  norace uint8_t  *ubx_ptr_prev;        // for debugging
  norace uint8_t  *msg_low, *msg_high;  // paranoid limits
  norace uint8_t  *msg_start;           // paranoid where cur msg starts


  /*
   * Instrumentation, Stats
   */
  norace dt_gps_proto_stats_t  ubx_stats;
  norace ubx_other_stats_t     ubx_other_stats;

  /*
   * ubx_reset: reset ubxbin proto state
   *
   * Does not tell the outside world that anything
   * has happened via GPSProto.msgAbort.
   */
  inline void ubx_reset() {
    ubx_stats.resets++;
    ubx_state_prev = ubx_state;
    ubx_state = UBXS_SYNC1;
    ubx_chk_a = 0;
    ubx_chk_b = 0;
    if (ubx_ptr) {
      ubx_ptr_prev = ubx_ptr;
      ubx_ptr = NULL;
      call MsgBuf.msg_abort();
    }
  }


  /*
   * ubx_restart_abort: reset and tell interested parties (typically
   * the driver layer).
   *
   * First reset the ubxbin protocol state and tell interested parties
   * that the current message is being aborted.
   *
   * Restart_Aborts get generated internally from the Proto
   * engine.
   */
  inline void ubx_restart_abort(uint16_t where) {
    atomic {
      ubx_reset();
      signal GPSProto.protoAbort(where);
    }
  }


  command void GPSProto.rx_timeout() {
    atomic {
      ubx_stats.rx_timeouts++;
      ubx_reset();
    }
  }


  /*
   * An rx_error occurred.  The underlying comm h/w isn't happy
   * Also throw a GPSProto.msgAbort to do reasonable things with
   * the underlying driver state machine.
   */
  command void GPSProto.rx_error(uint16_t gps_errors) {
    atomic {
      ubx_stats.rx_errors++;
      if (gps_errors & GPSPROTO_RXERR_FRAMING)
        ubx_stats.rx_framing++;
      if (gps_errors & GPSPROTO_RXERR_OVERRUN)
        ubx_stats.rx_overrun++;
      if (gps_errors & GPSPROTO_RXERR_PARITY)
        ubx_stats.rx_parity++;
      ubx_reset();
    }
  }


  command void GPSProto.resetStats() {
      ubx_stats.starts           = 0;
      ubx_stats.complete         = 0;
      ubx_stats.ignored          = 0;
      ubx_stats.resets           = 0;
      ubx_stats.too_small        = 0;
      ubx_stats.too_big          = 0;
      ubx_stats.chksum_fail      = 0;
      ubx_stats.rx_timeouts      = 0;
      ubx_stats.rx_errors        = 0;
      ubx_stats.rx_framing       = 0;
      ubx_stats.rx_overrun       = 0;
      ubx_stats.rx_parity        = 0;
      ubx_stats.proto_start_fail = 0;
      ubx_stats.proto_end_fail   = 0;
  }


  command void GPSProto.logStats() {
    dt_header_t hdr;
    dt_header_t *hp;

    hp = &hdr;
    hp->len   = sizeof(hdr) + sizeof(ubx_stats);
    hp->dtype = DT_GPS_PROTO_STATS;
    atomic {
      call Collect.collect((void *) &hdr, sizeof(hdr),
                 (void *) &ubx_stats, sizeof(ubx_stats));
      call GPSProto.resetStats();
    }
  }


  void chk_accum(uint8_t byte) {
    ubx_chk_a += byte;
    ubx_chk_b += ubx_chk_a;
  }


  async command void GPSProto.byteAvail(uint8_t byte) {
    switch(ubx_state) {
      case UBXS_SYNC1:
	if (byte != UBX_SYNC1) {
          ubx_stats.ignored++;
	  return;
        }
        ubx_state_prev = ubx_state;
	ubx_state = UBXS_SYNC2;
	return;

      case UBXS_SYNC2:
	if (byte == UBX_SYNC1) {       // got start again.  stay, good dog
          ubx_stats.ignored++;          // previous byte got ignored
	  return;
        }
	if (byte != UBX_SYNC2) {       // not what we want.  restart
          ubx_stats.proto_start_fail++; // weird, count it
	  ubx_restart_abort(1);
	  return;
	}
        ubx_state_prev = ubx_state;
	ubx_state = UBXS_CLASS;
        ubx_stats.starts++;
	return;

      case UBXS_CLASS:
        ubx_class = byte;
        chk_accum(byte);
        ubx_state_prev = ubx_state;
	ubx_state = UBXS_ID;
        return;

      case UBXS_ID:
        ubx_id = byte;
        chk_accum(byte);
        ubx_state_prev = ubx_state;
	ubx_state = UBXS_LEN_LSB;
        return;

      case UBXS_LEN_LSB:
	ubx_left = byte;
        chk_accum(byte);
        ubx_state_prev = ubx_state;
	ubx_state = UBXS_LEN_MSB;
	return;

      case UBXS_LEN_MSB:
	ubx_left |= (byte << 8);
        chk_accum(byte);
        /* smallest message has UBX_LEN of 0 */
	if (ubx_left > UBX_MAX_MSG) {
          if (ubx_left > ubx_other_stats.largest_seen)
            /*
             * largest_seen is the largest we have ever seen
             * including those that are bigger then our
             * max.
             */
            ubx_other_stats.largest_seen = ubx_left;
	  ubx_stats.too_big++;
	  ubx_restart_abort(2);
	  return;
	}
        if (ubx_left > ubx_other_stats.max_seen)
          ubx_other_stats.max_seen = ubx_left;
        if (ubx_left > ubx_other_stats.largest_seen)
            ubx_other_stats.largest_seen = ubx_left;
        ubx_ptr_prev = ubx_ptr;
        ubx_ptr = call MsgBuf.msg_start(ubx_left + UBX_OVERHEAD);
        if (!ubx_ptr) {
          ubx_other_stats.no_buffer++;
          ubx_restart_abort(3);
          return;
        }
        msg_start = ubx_ptr;
        signal GPSProto.msgStart(ubx_left + UBX_OVERHEAD);
        ubx_state_prev = ubx_state;
	ubx_state = UBXS_PAYLOAD;
        *ubx_ptr++ = UBX_SYNC1;
        *ubx_ptr++ = UBX_SYNC2;
        *ubx_ptr++ = ubx_class;
        *ubx_ptr++ = ubx_id;
        *ubx_ptr++ = ubx_left & 0xff;
        *ubx_ptr++ = (ubx_left >> 8) & 0xff;
        msg_low         = ubx_ptr;
        msg_high        = ubx_ptr + ubx_left - 1;
	return;

      case UBXS_PAYLOAD:
        if (ubx_ptr < msg_low || ubx_ptr > msg_high)
          call Panic.panic(PANIC_GPS, 136, (parg_t) ubx_ptr,
                           (parg_t) msg_low, (parg_t) msg_high, 0);

        /* look for SOP corruption, we've seen the 1st 4 wacked */
        if ((msg_start[0] != UBX_SYNC1) || (msg_start[1] != UBX_SYNC2))
          call Panic.panic(PANIC_GPS, 137, (parg_t) ubx_ptr,
                           (parg_t) msg_start, msg_start[0], msg_start[1]);
        *ubx_ptr++ = byte;
        chk_accum(byte);
	ubx_left--;
	if (ubx_left == 0) {
          ubx_state_prev = ubx_state;
	  ubx_state = UBXS_CHK_A;
          msg_low  = msg_high + 1;
          msg_high = msg_low;
        }
	return;

      case UBXS_CHK_A:
        if (ubx_ptr < msg_low || ubx_ptr > msg_high)
          call Panic.panic(PANIC_GPS, 136, (parg_t) ubx_ptr,
                           (parg_t) msg_low, (parg_t) msg_high, 0);
        *ubx_ptr++ = byte;
        if (byte != ubx_chk_a) {
	  ubx_stats.chksum_fail++;
	  ubx_restart_abort(4);
	  return;
        }
        ubx_state_prev = ubx_state;
	ubx_state = UBXS_CHK_B;
        msg_low  = msg_high + 1;
        msg_high = msg_low;
	return;

      case UBXS_CHK_B:
        if (ubx_ptr < msg_low || ubx_ptr > msg_high)
          call Panic.panic(PANIC_GPS, 136, (parg_t) ubx_ptr,
                           (parg_t) msg_low, (parg_t) msg_high, 0);
        *ubx_ptr++ = byte;
	if (byte != ubx_chk_b) {
	  ubx_stats.chksum_fail++;
	  ubx_restart_abort(5);
	  return;
	}
        ubx_ptr_prev = ubx_ptr;
        ubx_ptr = NULL;
        ubx_state_prev = ubx_state;
        ubx_state = UBXS_SYNC1;
        ubx_stats.complete++;
        signal GPSProto.msgEnd();
        call MsgBuf.msg_complete();
	return;

      default:
	call Panic.warn(PANIC_GPS, 135, ubx_state, 0, 0, 0);
	ubx_restart_abort(7);
	return;
    }
  }

        event void Collect.collectBooted() { }
  async event void Panic.hook() { }
}
