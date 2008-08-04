/*
 * Copyright (c) 2008 Eric B. Decker
 * All rights reserved.
 *
 * @author Eric B. Decker (cire831@gmail.com)
 * @date 28 May 2008
 *
 * Handle an incoming SIRF binary byte stream assembling it into
 * protocol messages and then process the ones we are interested in.
 *
 * A single buffer is used which assumes that the processing occurs
 * fairly quickly.  In our case we copy the data over to the data
 * collector.
 *
 * There is room left at the front of the msg buffer to put the data
 * collector header.
 *
 * Since message collection happens at interrupt level (async) and
 * data collection is a syncronous actvity provisions must be made
 * for handing the message off to task level.  While this is occuring
 * it is possible for additional bytes to arrive at interrupt level.
 * We handle this but using an overflow buffer.  When the task finishes
 * with the current message then it will flush the overflow buffer
 * back through the state machine to handle the characters.  It is
 * assumed that only a smaller number of bytes will need to be handled
 * this way and will be at most smaller than one packet.
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
    interface Collect;
    interface Panic;
    interface LocalTime<TMilli>;
  }
}

implementation {

  /*
   * gpsm_length is listed as norace.  The main state machine cycles and
   * references gpsm_length.  When a message is completed, on_overflow is set
   * which locks out the state machine and prevents gpsm_length from getting
   * change out from underneath us.
   */

  gpsm_state_t    gpsm_state;		// message collection state
  norace uint16_t gpsm_length;		// length of payload
  uint16_t        gpsm_cur_chksum;	// running chksum of payload

#define GPS_OVR_SIZE 16

  uint8_t  gpsm_msg[GPS_BUF_SIZE];
  uint8_t  gpsm_overflow[GPS_OVR_SIZE];
  uint8_t  gpsm_nxt;		        // where we are in the buffer
  uint8_t  gpsm_left;			// working copy
  bool     on_overflow;

  /*
   * Error counters
   */
  uint16_t gpsm_overflow_full;
  uint8_t  gpsm_overflow_max;
  uint16_t gpsm_too_big;
  uint16_t gpsm_chksum_fail;
  uint16_t gpsm_proto_fail;


  task void gps_msg_task() {
    dt_gps_raw_nt *gdp;
    uint8_t i, max;

    gdp = (dt_gps_raw_nt *) gpsm_msg;
    gdp->len = DT_HDR_SIZE_GPS_RAW + SIRF_OVERHEAD + gpsm_length;
    gdp->dtype = DT_GPS_RAW;
    gdp->chip  = DT_GPS_RAW_SIRF3;
    gdp->stamp_mis = call LocalTime.get();
    call Collect.collect(gpsm_msg, gdp->len);
    atomic {
      /*
       * note: gpsm_nxt gets reset on first call to GPSByte.byte_avail()
       * The only way to be here is if gps_msg_task has been posted which
       * means that on_overflow is true.  We simply need to look at gpsm_nxt
       * which will be > 0 if we have something that needs to be drained.
       */
      max = gpsm_nxt;
      on_overflow = FALSE;
      for (i = 0; i < max; i++)
	call GPSByte.byte_avail(gpsm_overflow[i]); // BRK_GPS_OVR
    }
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

    if (on_overflow) {		// BRK_GOT_CHR
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
	gpsm_length = byte << 8;		// data fields are big endian
	gpsm_msg[gpsm_nxt++] = byte;
	gpsm_state = GPSM_LEN_2;
	return;

      case GPSM_LEN_2:
	gpsm_length |= byte;
	gpsm_left = byte;
	gpsm_msg[gpsm_nxt++] = byte;
	gpsm_state = GPSM_PAYLOAD;
	gpsm_cur_chksum = 0;
	if (gpsm_length >= (GPS_BUF_SIZE - GPS_OVERHEAD)) {
	  gpsm_too_big++;
	  gpsm_state = GPSM_START;
	  return;
	}
	return;

      case GPSM_PAYLOAD:
	gpsm_msg[gpsm_nxt++] = byte;
	gpsm_cur_chksum += byte;
	gpsm_left--;
	if (gpsm_left == 0)
	  gpsm_state = GPSM_CHK;
	return;

      case GPSM_CHK:
	gpsm_msg[gpsm_nxt++] = byte;
	gpsm_state = GPSM_CHK_2;
	return;

      case GPSM_CHK_2:
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
	gpsm_nxt = 0;
	gpsm_state = GPSM_START;
	post gps_msg_task();
	return;

      default:
	call Panic.panic(PANIC_GPS, 100, gpsm_state, 0, 0, 0);
	return;
    }
  }
}
