/*
 * Copyright (c) 2017, Eric B. Decker
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 *
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * @author Eric B. Decker (cire831@gmail.com)
 * @date 21 April 2017
 *
 * Handle an incoming SIRF binary byte stream assembling it into protocol
 * messages.  Assemble into GPSMsgs.  Processing of the incoming msgs will
 * be handled by upper layer processors.
 */

#include <panic.h>
#include <platform_panic.h>
#include <sirf.h>

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

  /*
   * Error counters
   */
  norace uint16_t sirfbin_too_big;
  norace uint16_t sirfbin_no_buffer;    /* no buffer/msg available */
  norace uint16_t sirfbin_max_seen;     /* max length seen */
  norace uint16_t sirfbin_chksum_fail;
  norace uint16_t sirfbin_proto_fail;

  /*
   * external world is blowing us up.  No need to tell
   * the external world that we are aborting the message.
   */
  command void GPSProto.reset() {
    atomic {
      sirfbin_state_prev = sirfbin_state;
      sirfbin_state = SBS_START;
      if (sirfbin_ptr) {
        sirfbin_ptr_prev = sirfbin_ptr;
        sirfbin_ptr = NULL;
        call GPSBuffer.msg_abort();
      }
    }
  }


  inline void sirfbin_restart() {
    atomic {
      sirfbin_state_prev = sirfbin_state;
      sirfbin_state = SBS_START;
      if (sirfbin_ptr) {
        sirfbin_ptr_prev = sirfbin_ptr;
        sirfbin_ptr = NULL;
        call GPSBuffer.msg_abort();
      }
      signal GPSProto.msgAbort();
    }
  }


  async command void GPSProto.byteAvail(uint8_t byte) {
    uint16_t chksum;

    switch(sirfbin_state) {
      case SBS_START:
	if (byte != SIRFBIN_A0)
	  return;
	sirfbin_state = SBS_START_2;
	return;

      case SBS_START_2:
	if (byte == SIRFBIN_A0)                 // got start again.  stay, good dog
	  return;
	if (byte != SIRFBIN_A2) {		// not what we want.  restart
	  sirfbin_restart();
	  return;
	}
	sirfbin_state = SBS_LEN;
	return;

      case SBS_LEN:
	sirfbin_left = byte << 8;		// data fields are big endian
	sirfbin_state = SBS_LEN_2;
	return;

      case SBS_LEN_2:
	sirfbin_left |= byte;
        if (sirfbin_left > sirfbin_max_seen)
          sirfbin_max_seen = sirfbin_left;
	if (sirfbin_left >= SIRFBIN_MAX_MSG) {
	  sirfbin_too_big++;
	  sirfbin_restart();
	  return;
	}
        sirfbin_ptr = call GPSBuffer.msg_start(sirfbin_left + SIRFBIN_OVERHEAD);
        sirfbin_ptr_prev = sirfbin_ptr;
        if (!sirfbin_ptr) {
          sirfbin_no_buffer++;
          sirfbin_restart();
          return;
        }
        signal GPSProto.msgStart(sirfbin_left + SIRFBIN_OVERHEAD);
	sirfbin_state = SBS_PAYLOAD;
        sirfbin_chksum = 0;
        *sirfbin_ptr++ = SIRFBIN_A0;
        *sirfbin_ptr++ = SIRFBIN_A2;
        *sirfbin_ptr++ = (sirfbin_left >> 8) & 0xff;
        *sirfbin_ptr++ = sirfbin_left & 0xff;
	return;

      case SBS_PAYLOAD:
        *sirfbin_ptr++ = byte;
	sirfbin_chksum += byte;
	sirfbin_left--;
	if (sirfbin_left == 0)
	  sirfbin_state = SBS_CHK;
	return;

      case SBS_CHK:
        *sirfbin_ptr++ = byte;
	sirfbin_state = SBS_CHK_2;
	return;

      case SBS_CHK_2:
        *sirfbin_ptr++ = byte;
	chksum = sirfbin_ptr[-2] << 8 | byte;
	if (chksum != sirfbin_chksum) {
	  sirfbin_chksum_fail++;
	  sirfbin_restart();
	  return;
	}
	sirfbin_state = SBS_END;
	return;

      case SBS_END:
        *sirfbin_ptr++ = byte;
	if (byte != SIRFBIN_B0) {
	  sirfbin_proto_fail++;
	  sirfbin_restart();
	  return;
	}
	sirfbin_state = SBS_END_2;
	return;

      case SBS_END_2:
        *sirfbin_ptr++ = byte;
	if (byte != SIRFBIN_B3) {
	  sirfbin_proto_fail++;
	  sirfbin_restart();
	  return;
	}
        signal GPSProto.msgEnd();
        call GPSBuffer.msg_complete();
	return;

      default:
	call Panic.warn(PANIC_GPS, 135, sirfbin_state, 0, 0, 0);
	sirfbin_restart();
	return;
    }
  }

  async event void Panic.hook() { }
}
