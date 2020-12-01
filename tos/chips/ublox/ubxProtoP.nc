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
    UBXS_START = 0,                     /* 0xB5, 'u' */
                                        /* or '$' for NMEA */

    UBXS_SYNC2,                         /* 0x62, 'b' */
    UBXS_CLASS,
    UBXS_ID,
    UBXS_LEN_LSB,                       /* len lsb */
    UBXS_LEN_MSB,                       /* len msb */
    UBXS_PAYLOAD,
    UBXS_CHKA,                          /* chkA byte */
    UBXS_CHKB,                          /* chkB byte */

    UBXS_NMEA_COLLECT,
    UBXS_NMEA_CHK0,                     /* waiting for 1st chksum byte */
    UBXS_NMEA_CHK1,                     /* waiting for 2nd chksum byte */
    UBXS_NMEA_0D,                       /* terminator, CR, \r          */
    UBXS_NMEA_0A,                       /* terminator, LF, \n          */
  } ubxs_t;                             /* ubx_state type              */


  norace ubxs_t    ubx_state;           // message collection state
  norace ubxs_t    ubx_state_prev;      // debugging
  norace uint8_t   ubx_class;           // message class
  norace uint8_t   ubx_id;              // message id
  norace uint16_t  ubx_left;            // payload bytes left
  norace uint8_t   ubx_chkA;            // fletcher checksum
  norace uint8_t   ubx_chkB;            // fletcher checksum
  norace uint8_t   ubx_nmea_chk;        // nmea checksum
  norace uint8_t   ubx_nmea_len;        // accum length
  norace uint8_t  *ubx_ptr;             // where to stash incoming bytes
  norace uint8_t  *ubx_ptr_prev;        // for debugging
  norace uint8_t  *msg_low, *msg_high;  // paranoid limits
  norace uint8_t  *msg_start;           // paranoid where cur msg starts

#define MAX_NMEA_MSG  90

  norace uint8_t   nmea_buf[MAX_NMEA_MSG];


  /*
   * Instrumentation, Stats
   */
  norace dt_gps_proto_stats_t  ubx_stats;
  norace ubx_other_stats_t     ubx_other_stats;

  void ubx_change_state(ubxs_t new_state) {
    ubx_state_prev = ubx_state;
    ubx_state = new_state;
  }

  /*
   * ubx_reset: reset ubxbin proto state
   *
   * Does not tell the outside world that anything
   * has happened via GPSProto.msgAbort.
   */
  inline void ubx_reset() {
    ubx_stats.resets++;
    ubx_change_state(UBXS_START);
    ubx_chkA = 0;
    ubx_chkB = 0;
    ubx_nmea_chk = 0;
    ubx_nmea_len = 0;
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


  command void GPSProto.restart() {
    if (ubx_state != UBXS_START)
      ubx_restart_abort(0);             /* restart */
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
    ubx_chkA += byte;
    ubx_chkB += ubx_chkA;
  }


  void nmea_accum_byte(uint8_t byte) {
    ubx_nmea_chk ^= byte;
    if (ubx_nmea_len >= MAX_NMEA_MSG)
      return;
    nmea_buf[ubx_nmea_len++] = byte;
  }


  uint8_t htoi(uint8_t byte) {
    if (byte >= '0' && byte <= '9')
      return byte - '0';
    if (byte >= 'A' && byte <= 'F')
      return byte - 'A' + 10;
    if (byte >= 'a' && byte <= 'f')
      return byte - 'a' + 10;
    return 0xff;
  }

  /**
   * GPSProto.byteAvail: called with a new byte for the proto engine
   *
   * input:  byte       input byte
   * return: TRUE       just finished a message
   *         FALSE      otherwise.
   */
  uint8_t last_byte;

  command bool GPSProto.byteAvail(uint8_t byte) {
    uint8_t i;

    last_byte = byte;
    while (TRUE) {
      switch(ubx_state) {
        case UBXS_START:
          if (byte == '$') {
            ubx_change_state(UBXS_NMEA_COLLECT);
            ubx_nmea_chk = 0;
            ubx_nmea_len = 1;
            nmea_buf[0] = byte;
            signal GPSProto.msgStart(MAX_NMEA_MSG);
            break;
          }
          if (byte != UBX_SYNC1) {
            ubx_stats.ignored++;
            break;
          }
          ubx_change_state(UBXS_SYNC2);
          break;

        case UBXS_SYNC2:
          if (byte == UBX_SYNC1) {        // got start again.  stay, good dog
            ubx_stats.ignored++;          // previous byte got ignored
            break;
          }
          if (byte == '$') {
            ubx_stats.ignored++;          // previous byte got ignored
            ubx_change_state(UBXS_NMEA_COLLECT);
            ubx_nmea_chk = 0;
            ubx_nmea_len = 1;
            nmea_buf[0] = byte;
            signal GPSProto.msgStart(MAX_NMEA_MSG);
            break;
          }
          if (byte != UBX_SYNC2) {        // not what we want.  restart
            ubx_stats.proto_start_fail++; // weird, count it
            ubx_restart_abort(1);
            break;
          }
          ubx_change_state(UBXS_CLASS);
          ubx_stats.starts++;
          break;

        case UBXS_CLASS:
          ubx_chkA  = byte;               // restart fletcher checksum
          ubx_chkB  = byte;
          ubx_class = byte;
          ubx_change_state(UBXS_ID);
          break;

        case UBXS_ID:
          ubx_id = byte;
          chk_accum(byte);
          ubx_change_state(UBXS_LEN_LSB);
          break;

        case UBXS_LEN_LSB:
          ubx_left = byte;
          chk_accum(byte);
          ubx_change_state(UBXS_LEN_MSB);
          break;

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
            break;
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
            break;
          }
          msg_start = ubx_ptr;
          signal GPSProto.msgStart(ubx_left + UBX_OVERHEAD);
          ubx_change_state(UBXS_PAYLOAD);
          *ubx_ptr++ = UBX_SYNC1;
          *ubx_ptr++ = UBX_SYNC2;
          *ubx_ptr++ = ubx_class;
          *ubx_ptr++ = ubx_id;
          *ubx_ptr++ = ubx_left & 0xff;
          *ubx_ptr++ = (ubx_left >> 8) & 0xff;
          msg_low    = ubx_ptr;
          msg_high   = ubx_ptr + ubx_left - 1;
          break;

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
            ubx_change_state(UBXS_CHKA);
            msg_low  = msg_high + 1;
            msg_high = msg_low;
          }
          break;

        case UBXS_CHKA:
          if (ubx_ptr < msg_low || ubx_ptr > msg_high)
            call Panic.panic(PANIC_GPS, 138, (parg_t) ubx_ptr,
                             (parg_t) msg_low, (parg_t) msg_high, 0);
          *ubx_ptr++ = byte;
          if (byte != ubx_chkA) {
            ubx_stats.chksum_fail++;
            ubx_restart_abort(4);
            break;
          }
          ubx_change_state(UBXS_CHKB);
          msg_low  = msg_high + 1;
          msg_high = msg_low;
          break;

        case UBXS_CHKB:
          if (ubx_ptr < msg_low || ubx_ptr > msg_high)
            call Panic.panic(PANIC_GPS, 139, (parg_t) ubx_ptr,
                             (parg_t) msg_low, (parg_t) msg_high, 0);
          *ubx_ptr++ = byte;
          if (byte != ubx_chkB) {
            ubx_stats.chksum_fail++;
            ubx_restart_abort(5);
            break;
          }
          ubx_ptr_prev = ubx_ptr;
          ubx_ptr = NULL;
          ubx_change_state(UBXS_START);
          ubx_stats.complete++;
          WIGGLE_EXC; WIGGLE_EXC;
          signal GPSProto.msgEnd();
          call MsgBuf.msg_complete();
          return TRUE;

        case UBXS_NMEA_COLLECT:
          /*
           * check to see if the message will still fit.  6 is the number
           * of extra bytes at the end, we use '*xx\r\n\0'
           *
           * NMEA is printable ascii only between 0x20 (space) and 0x7e (~).
           */
          if (byte < 0x20 || byte > 0x7e) {
            /* oops, bad byte */
            WIGGLE_EXC; WIGGLE_TELL; WIGGLE_TELL; WIGGLE_TELL; WIGGLE_EXC;
            ubx_restart_abort(6);
            break;
          }
          if (ubx_nmea_len >= (MAX_NMEA_MSG - 6)) {
            /* oops too big. */
            WIGGLE_EXC; WIGGLE_TELL; WIGGLE_TELL; WIGGLE_EXC;
            ubx_other_stats.nmea_too_big++;
            ubx_restart_abort(7);
            break;
          }
          if (byte == '*') {
            nmea_buf[ubx_nmea_len++] = byte;
            ubx_change_state(UBXS_NMEA_CHK0);
            break;
          }
          nmea_accum_byte(byte);
          break;

        case UBXS_NMEA_CHK0:
          nmea_buf[ubx_nmea_len++] = byte;
          ubx_chkA = htoi(byte);
          ubx_change_state(UBXS_NMEA_CHK1);
          break;

        case UBXS_NMEA_CHK1:
          nmea_buf[ubx_nmea_len++] = byte;
          nmea_buf[ubx_nmea_len++] = '\r';
          nmea_buf[ubx_nmea_len++] = '\n';
          nmea_buf[ubx_nmea_len++] = '\0';
          byte = (ubx_chkA << 4) | htoi(byte);
          if (byte == ubx_nmea_chk) {
            /* good checksum, add to message queue */
            ubx_other_stats.nmea_good++;
            ubx_ptr_prev = ubx_ptr;
            ubx_ptr = call MsgBuf.msg_start(ubx_nmea_len);
            if (!ubx_ptr) {
              ubx_other_stats.no_buffer++;
              ubx_restart_abort(8);
              break;
            }
            msg_start = ubx_ptr;
            for (i = 0; i < ubx_nmea_len; i++)
              *ubx_ptr++ = nmea_buf[i];
            ubx_ptr_prev = ubx_ptr;
            ubx_ptr = NULL;
            ubx_change_state(UBXS_NMEA_0D);
            WIGGLE_EXC; WIGGLE_EXC;
            signal GPSProto.msgEnd();
            call MsgBuf.msg_complete();
            return TRUE;
          }
          /* oops */
          ubx_other_stats.nmea_bad_chk++;
          ubx_restart_abort(9);
          break;

        case UBXS_NMEA_0D:
          if (byte != 0x0d) {
            ubx_change_state(UBXS_START);
            continue;
          }
          ubx_change_state(UBXS_NMEA_0A);
          break;

        case UBXS_NMEA_0A:
          if (byte != 0x0a) {
            ubx_change_state(UBXS_START);
            continue;
          }
          ubx_change_state(UBXS_START);
          break;

        default:
          call Panic.warn(PANIC_GPS, 135, ubx_state, 0, 0, 0);
          ubx_restart_abort(10);
          break;
      }
      break;
    }
    return FALSE;                       /* msg incomplete */
  }


  command uint16_t GPSProto.fletcher8(uint8_t *ptr, uint16_t len) {
    uint8_t chk_a, chk_b;

    chk_a = chk_b = 0;
    while (len) {
      chk_a += *ptr++;
      chk_b += chk_a;
      len--;
    }
    return ((uint16_t) chk_a << 8) | chk_b;
  }


  command uint8_t GPSProto.nema_sum(uint8_t *ptr, uint16_t len) {
    uint8_t chk;

    chk = 0;
    while (len) {
      chk ^= *ptr++;
      len--;
    }
    return chk;
  }


        event void Collect.collectBooted() { }
  async event void Panic.hook() { }
}
