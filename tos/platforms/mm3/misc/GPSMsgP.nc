/*
 * Copyright (c) 2008 Eric B. Decker
 * All rights reserved.
 *
 * @author Eric B. Decker (cire831@gmail.com)
 * @date 28 May 2008
 */

#include "panic.h"
#include "sd_blocks.h"
#include "sirf.h"

/*
 * GPS Message level states.  Where in the message is the state machine
 */
typedef enum {
  GPSM_START = 1,
  GPSM_START_2,
  GPSM_LEN,
  GPSM_LEN_2,
  GPSM_PAYLOAD,
  GPSM_CHK,
  GPSM_CHK_2,
  GPSM_END,
  GPSM_END_2,
} gpsm_state_t;


module GPSMsgP {
  provides {
    interface Init;
    interface StdControl as GPSMsgControl;
    interface GPSByte;
  }
  uses {
    interface Panic;
  }
}

implementation {

  norace gpsm_state_t gpsm_state;	/* message collection state */
  norace uint16_t     gpsm_length;	/* length of payload */
  norace uint16_t     gpsm_cur_chksum;	/* running chksum of payload */

#define GPS_OVR_SIZE 16

  uint8_t gpsm_msg[GPS_BUF_SIZE];
  uint8_t gpsm_overflow[GPS_OVR_SIZE];
  uint8_t gpsm_nxt;		        /* where we are in the buffer */
  bool    on_overflow;
  bool    bail;

  /*
   * Error counters
   */
  norace uint16_t gpsm_overflow_full;
  norace uint8_t  gpsm_overflow_max;
  norace uint16_t gpsm_too_big;
  norace uint16_t gpsm_chksum_fail;
  norace uint16_t gpsm_proto_fail;

  /*
   *
   */
  task void gps_msg_task() {
    nop();
  }


  command error_t GPSMsgControl.start() {
    atomic {
      gpsm_state = GPSM_START;
      memset(gpsm_msg, 0, sizeof(gpsm_msg));
      on_overflow = FALSE;
      return SUCCESS;
    }
  }


  command error_t GPSMsgControl.stop() {
    nop();
    return SUCCESS;
  }


  command error_t Init.init() {
    gpsm_overflow_full = 0;
    gpsm_overflow_max  = 0;
    gpsm_too_big = 0;
    gpsm_chksum_fail = 0;
    gpsm_proto_fail = 0;
    call GPSMsgControl.start();
    return SUCCESS;
  }


  async command void GPSByte.byte_avail(uint8_t byte) {
    uint16_t chksum;

    if (on_overflow) {
      if (gpsm_nxt >= GPS_OVR_SIZE) {
	/*
	 * full, throw them all away.
	 */
	gpsm_nxt = 0;
	gpsm_overflow_full++;
	return;
      }
      gpsm_overflow[gpsm_nxt++] = byte;
      if (gpsm_nxt > gpsm_overflow_max)
	gpsm_overflow_max = gpsm_nxt;
      return;
    }

    switch(gpsm_state) {
      case GPSM_START:
	if (byte != SIRF_BIN_START)
	  return;
	gpsm_nxt = GPS_START_OFFSET;
	gpsm_msg[gpsm_nxt++] = byte;
	gpsm_state = GPSM_START_2;
	bail = FALSE;
	return;

      case GPSM_START_2:
	if (byte == SIRF_BIN_START)		// got start again.  stay
	  return;
	if (byte != SIRF_BIN_START_2) {		// not what we want.  restart
	  gpsm_state = GPSM_START;
	  return;
	}
	gpsm_msg[gpsm_nxt++] = byte;
	gpsm_state = GPSM_LEN;
	return;

      case GPSM_LEN:
	gpsm_length = byte << 8;
	gpsm_msg[gpsm_nxt++] = byte;
	gpsm_state = GPSM_LEN_2;
	return;

      case GPSM_LEN_2:
	gpsm_length |= byte;
	gpsm_msg[gpsm_nxt++] = byte;
	gpsm_state = GPSM_PAYLOAD;
	gpsm_cur_chksum = 0;
	if (gpsm_length >= (GPS_BUF_SIZE - GPS_OVERHEAD)) {
	  bail = TRUE;
	  gpsm_too_big++;
	}
	return;

      case GPSM_PAYLOAD:
	if (!bail)
	  gpsm_msg[gpsm_nxt++] = byte;
	gpsm_cur_chksum += byte;
	gpsm_length--;
	if (gpsm_length == 0)
	  gpsm_state = GPSM_CHK;
	return;

      case GPSM_CHK:
	gpsm_msg[gpsm_nxt++] = byte;
	gpsm_state = GPSM_CHK_2;
	return;

      case GPSM_CHK_2:
	if (bail) {
	  gpsm_state = GPSM_START;
	  return;
	}
	gpsm_msg[gpsm_nxt++] = byte;
	chksum = gpsm_msg[gpsm_nxt - 2] << 8 | byte;
	if (chksum != gpsm_cur_chksum) {
	  gpsm_chksum_fail++;
	  gpsm_state = GPSM_START;
	  return;
	}
	gpsm_state = GPSM_END;
	return;

      case GPSM_END:
	gpsm_msg[gpsm_nxt++] = byte;
	if (byte != SIRF_BIN_END) {
	  gpsm_proto_fail++;
	  gpsm_state = GPSM_START;
	  return;
	}
	gpsm_state = GPSM_END_2;
	return;

      case GPSM_END_2:
	gpsm_msg[gpsm_nxt++] = byte;
	if (byte != SIRF_BIN_END_2) {
	  gpsm_proto_fail++;
	  gpsm_state = GPSM_START;
	  return;
	}
	on_overflow = TRUE;
	gpsm_state = GPSM_START;
	gpsm_nxt = 0;
	post gps_msg_task();
	return;

      default:
	call Panic.panic(PANIC_GPS, 100, gpsm_state, 0, 0, 0);
	return;
    }
  }
}
