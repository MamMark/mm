/*
 * Copyright (c) 2020, Eric B. Decker
 * Copyright (c) 2020, David Lehrian
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
 * DockComm protocol processor.
 */

#include <panic.h>
#include <platform_panic.h>
#include <dockcomm.h>

#ifndef PANIC_DOCK
enum {
  __pcode_dock = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_DOCK __pcode_dock
#endif

/*
 * Instrumentation, Stats
 *
 * rx_errors: gets popped when either an rx_timeout, or any rx error,
 * rx_error includes FramingError, ParityError, and OverrunError.
 *
 * majority of instrumentation stats are defined by the
 * dt_gps_proto_stats_t structure in typed_data.h.
 */

typedef struct {
  uint32_t starts;                    /* number of packets started */
  uint32_t complete;                  /* number completed successfully */
  uint32_t ignored;                   /* number of bytes ignored */
  uint16_t resets;                    /* protocol resets (aborts) */
  uint16_t too_small;                 /* too small, aborted */
  uint16_t too_big;                   /* too large, aborted */
  uint16_t chksum_fail;               /* bad checksum */
  uint16_t rx_timeouts;               /* number of rx timeouts */
  uint16_t rx_errors;                 /* rx_error, comm h/w not happy */
  uint16_t rx_framing;                /* framing errors */
  uint16_t rx_overrun;                /* overrun errors */
  uint16_t rx_parity;                 /* parity errors  */
  uint16_t proto_start_fail;          /* proto fails at start of packet */
  uint16_t proto_end_fail;            /* proto fails at end   of packet */
} dc_proto_stats_t;


typedef struct {
  uint16_t no_buffer;                 /* no buffer/msg available */
  uint16_t max_seen;                  /* max legal seen */
  uint16_t largest_seen;              /* largest packet length seen */
} dc_other_stats_t;


module DockProtoP {
  provides {
    interface DockProto;
  }
  uses {
    interface MsgBuf;
    interface Panic;
  }
}
implementation {
  /*
   * DockComm Collector state.  Where in the message is the state
   * machine.  Used when collecting messages.
   */

  typedef enum {
    DCS_CHN      = 0,                   /* channel */
    DCS_TYPE,                           /* type    */
    DCS_LEN_LSB,                        /* len lsb */
    DCS_LEN_MSB,                        /* len msb */
    DCS_DATA,                           /* payload */
    DCS_CHKA,                           /* fletcher, chkA  */
    DCS_CHKB,                           /* fletcher, chkB  */
    DCS_SRSP,                           /* simple response */
  } dcs_t;                              /* dockcomm state  */


  dcs_t     dc_state;            // message collection state
  uint16_t  dc_left;             // payload bytes left
  uint16_t  dc_chksum;           // running chksum of payload
  uint8_t  *dc_ptr;              // where to stash incoming bytes
  uint8_t  *sb_low, *sb_high;    // paranoid limits
  uint8_t  *sb_start;            // paranoid where cur msg starts
  dc_hdr_t  dc_hdr;              // initial part being collected.
  uint8_t   dc_chkA;             // fetcher
  uint8_t   dc_chkB;             // fetcher


  /*
   * Instrumentation, Stats
   */
  norace dc_proto_stats_t  dc_stats;
  norace dc_other_stats_t  dc_other_stats;


  void chk_accum(uint8_t byte) {
    dc_chkA += byte;
    dc_chkB += dc_chkB;
  }


  /*
   * dc_reset: reset dc proto state
   *
   * Does not tell the outside world that anything
   * has happened via DockProto.msgAbort.
   */
  inline void dc_reset() {
    dc_stats.resets++;
    dc_state = DCS_CHN;
    if (dc_ptr) {
      dc_ptr = NULL;
      call MsgBuf.msg_abort();
    }
  }


  /*
   * dc_restart_abort: reset and tell interested parties (typically
   * the driver layer).
   *
   * First reset the dc protocol state and tell interested parties
   * that the current message is being aborted.
   *
   * Restart_Aborts get generated internally from the Proto
   * engine.
   */
  inline void dc_restart_abort(uint16_t where) {
    dc_reset();
    signal DockProto.protoAbort(where);
  }


  command void DockProto.protoRestart() {
    dc_reset();
  }


  command void DockProto.byteAvail(uint8_t byte) {
    switch(dc_state) {
      case DCS_CHN:
        dc_chkA = byte;                 /* initialize fletcher */
        dc_chkB = byte;
        dc_hdr.dc_chn = byte;
	dc_state = DCS_TYPE;
        dc_stats.starts++;
	return;

      case DCS_TYPE:
        chk_accum(byte);
        dc_hdr.dc_type = byte;
	dc_state = DCS_LEN_LSB;
	return;

      case DCS_LEN_LSB:
        chk_accum(byte);
	dc_left = byte;                 /* little endian, lsb */
	dc_state = DCS_LEN_MSB;
	return;

      case DCS_LEN_MSB:
        chk_accum(byte);
	dc_left |= (byte << 8);         /* msb */
        dc_hdr.dc_len = dc_left;
        dc_ptr = call MsgBuf.msg_start(dc_left + DC_OVERHEAD);
        if (!dc_ptr) {
          dc_other_stats.no_buffer++;
          dc_restart_abort(3);
          return;
        }
        sb_start = dc_ptr;
        signal DockProto.msgStart(dc_left + DC_OVERHEAD);
	dc_state  = DCS_DATA;
        *dc_ptr++ = dc_hdr.dc_chn;
        *dc_ptr++ = dc_hdr.dc_type;
        *dc_ptr++ = dc_hdr.dc_len & 0xff;
        *dc_ptr++ = dc_hdr.dc_len >> 8;
        sb_low    = dc_ptr;
        sb_high   = dc_ptr + dc_left - 1;
	return;

      case DCS_DATA:
        if (dc_ptr < sb_low || dc_ptr > sb_high)
          call Panic.panic(PANIC_DOCK, 136, (parg_t) dc_ptr,
                           (parg_t) sb_low, (parg_t) sb_high, 0);
        chk_accum(byte);
        *dc_ptr++ = byte;
	dc_left--;
	if (dc_left == 0) {
	  dc_state = DCS_CHKA;
          sb_low  = sb_high + 1;
          sb_high = sb_low;
        }
	return;

      case DCS_CHKA:
        if (dc_ptr < sb_low || dc_ptr > sb_high)
          call Panic.panic(PANIC_DOCK, 136, (parg_t) dc_ptr,
                           (parg_t) sb_low, (parg_t) sb_high, 0);
        *dc_ptr++ = byte;
        if (byte != dc_chkA) {          /* oops */
	  dc_stats.chksum_fail++;
	  dc_restart_abort(4);
          return;
        }
	dc_state = DCS_CHKB;
        sb_low  = sb_high + 1;
        sb_high = sb_low;
	return;

      case DCS_CHKB:
        if (dc_ptr < sb_low || dc_ptr > sb_high)
          call Panic.panic(PANIC_DOCK, 136, (parg_t) dc_ptr,
                           (parg_t) sb_low, (parg_t) sb_high, 0);
        *dc_ptr++ = byte;
        if (byte != dc_chkB) {          /* oops */
	  dc_stats.chksum_fail++;
	  dc_restart_abort(4);
          return;
        }
        dc_ptr = NULL;
        dc_state = DCS_CHN;
        dc_stats.complete++;
        signal DockProto.msgEnd();
        call MsgBuf.msg_complete();
	return;

      default:
	call Panic.warn(PANIC_DOCK, 135, dc_state, 0, 0, 0);
	dc_restart_abort(7);
	return;
    }
  }

  command void DockProto.rx_timeout() {
    dc_stats.rx_timeouts++;
    dc_reset();
  }


  /*
   * An rx_error occurred.  The underlying comm h/w isn't happy
   * Also throw a GPSProto.msgAbort to do reasonable things with
   * the underlying driver state machine.
   */
  command void DockProto.rx_error(uint16_t errors) {
    dc_stats.rx_errors++;
    dc_reset();
  }

  async event void Panic.hook() { }
}
