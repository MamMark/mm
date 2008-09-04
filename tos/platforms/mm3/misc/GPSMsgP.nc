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
#include "gps_msg.h"

/*
 * GPS Message Collector states.  Where in the message is the state machine.  Used
 * when collecting messages.
 */
typedef enum {
  COLLECT_START = 1,
  COLLECT_START_2,
  COLLECT_LEN,
  COLLECT_LEN_2,
  COLLECT_PAYLOAD,
  COLLECT_CHK,
  COLLECT_CHK_2,
  COLLECT_END,
  COLLECT_END_2,
} collect_state_t;


/*
 * GPS Message States.
 */

typedef enum {
  GPSM_DOWN = 0x10,
  GPSM_STARTING,
  GPSM_SHORT,				/* looking for hot fix */
  GPSM_LONG,				/* loading almanac */
  GPSM_STOPPING,
} gpsm_state_t;


module GPSMsgP {
  provides {
    interface Init;
    interface StdControl as GPSMsgControl;
    interface GPSMsg;
  }
  uses {
    interface Collect;
    interface Panic;
    interface LocalTime<TMilli>;
    interface Timer<TMilli> as MsgTimer;
    interface SplitControl as GPSControl;
    interface Surface;
    interface LogEvent;
  }
}

implementation {

  /*
   * The collection state machine cycles and references collect_length.
   * When a message is completed, on_overflow is set which locks out
   * the state machine and prevents collect_length from getting
   * changed out from underneath us.
   */

  collect_state_t collect_state;		// message collection state
  norace uint16_t collect_length;		// length of payload
  uint16_t        collect_cur_chksum;	// running chksum of payload

  uint8_t  collect_msg[GPS_BUF_SIZE];
  uint8_t  collect_overflow[GPS_OVR_SIZE];
  uint8_t  collect_nxt;		        // where we are in the buffer
  uint8_t  collect_left;			// working copy
  bool     on_overflow;

  /*
   * Error counters
   */
  uint16_t collect_overflow_full;
  uint8_t  collect_overflow_max;
  uint16_t collect_too_big;
  uint16_t collect_chksum_fail;
  uint16_t collect_proto_fail;
  uint32_t last_surfaced;
  uint32_t last_submerged;

  gpsm_state_t gpsm_state;

#ifdef notdef
  task void gps_msg_control_task() {
    switch (gpsm_state) {
      default:
	call Panic.panic(PANIC_GPS, 128, gpsm_state, 0, 0, 0);
	gpsm_state = GPSM_DOWN;
	call MsgTimer.stop();
	return;

      case GPSM_STARTING:
	call GPSControl.start();
	return;

      case GPSM_STOPPING:
	call MsgTimer.stop();
	call GPSControl.stop();
	return;
    }
  }
#endif


  command error_t Init.init() {
    gpsm_state = GPSM_DOWN;
    return SUCCESS;
  }


  event void GPSControl.startDone(error_t err) {
    gpsm_state = GPSM_SHORT;
    call MsgTimer.startOneShot(GPS_MSG_SHORT_WINDOW);
  }

  event void GPSControl.stopDone(error_t err) {
    gpsm_state = GPSM_DOWN;
  }


  /*
   * A surface event has occured.  Note that we are edge
   * triggered.  For the event to have happened we need to
   * have been submerged.
   */
  event void Surface.surfaced() {
    uint32_t t;

    t = call LocalTime.get();
    if (last_surfaced && (t - last_surfaced ) < 1024)
      call Panic.warn(PANIC_GPS, 129, 0, 0, 0, 0);
    last_surfaced = t;
    if (gpsm_state != GPSM_DOWN) {
      call Panic.warn(PANIC_GPS, 130, gpsm_state, 0, 0, 0);
      gpsm_state = GPSM_DOWN;
    }
    gpsm_state = GPSM_STARTING;
    call GPSControl.start();
  }

  event void Surface.submerged() {
    uint32_t t;

    t = call LocalTime.get();
    if (last_submerged && (t - last_surfaced ) < 1024)
      call Panic.panic(PANIC_GPS, 131, 0, 0, 0, 0);
    last_submerged = t;
    gpsm_state = GPSM_STOPPING;
    call MsgTimer.stop();
    call GPSControl.stop();
  }


  event void MsgTimer.fired() {
    switch (gpsm_state) {
      default:
	call Panic.panic(PANIC_GPS, 132, gpsm_state, 0, 0, 0);
	return;

      case GPSM_SHORT:
	gpsm_state = GPSM_LONG;
	call MsgTimer.startOneShot(GPS_MSG_LONG_WINDOW);
	return;

      case GPSM_LONG:
	gpsm_state = GPSM_STOPPING;
	call GPSControl.stop();
	return;
    }
  }


  /*
   * Process a Geodetic packet from the Sirf3.
   */
  void process_geodetic(gps_geodetic_nt *geop) {
    /*
     * Extract time and position data out
     */

    uint8_t gps_time_block[GPS_TIME_BLOCK_SIZE];
    uint8_t gps_pos_block[GPS_POS_BLOCK_SIZE];
    dt_gps_time_nt *timep;
    dt_gps_pos_nt *posp;

    timep = (dt_gps_time_nt*)gps_time_block;
    posp = (dt_gps_pos_nt*)gps_pos_block;

    timep->len = GPS_TIME_BLOCK_SIZE;
    timep->dtype = DT_GPS_TIME;
    timep->stamp_mis = call LocalTime.get();
    timep->chip_type = CHIP_GPS_SIRF3;
    timep->num_svs = geop->num_svs;
    timep->utc_year = geop->utc_year;
    timep->utc_month = geop->utc_month;
    timep->utc_day = geop->utc_day;
    timep->utc_hour = geop->utc_hour;
    timep->utc_min = geop->utc_min;
    timep->utc_millsec = geop->utc_sec;
    timep->clock_bias = geop->clock_bias;
    timep->clock_drift = geop->clock_drift;
  
    posp->len = GPS_POS_BLOCK_SIZE;
    posp->dtype = DT_GPS_POS;
    posp->stamp_mis = timep->stamp_mis;
    posp->chip_type = CHIP_GPS_SIRF3;
    posp->nav_type = geop->nav_type;
    posp->num_svs = geop->num_svs;
    posp->sats_seen = geop->sat_mask;
    posp->gps_lat = geop->lat;
    posp->gps_long = geop->lon;
    posp->ehpe = geop->ehpe;
    posp->hdop = geop->hdop;

    /*
     * Check for state change information
     */
    if (geop->nav_valid == 0) {

      call LogEvent.logEvent(DT_EVENT_GPS_ACQUIRED);
      call Collect.collect(gps_time_block, GPS_TIME_BLOCK_SIZE);
      call Collect.collect(gps_pos_block, GPS_POS_BLOCK_SIZE);

      /*
       * overdetermined.  For now if we are in the SHORT window
       * then power down because we got the fix.
       */
      if (gpsm_state == GPSM_SHORT) {
	call LogEvent.logEvent(DT_EVENT_GPS_FAST);
	gpsm_state = GPSM_STOPPING;
	call GPSControl.stop();
	return;
      }
    }
  }


  task void gps_msg_task() {
    dt_gps_raw_nt *gdp;
    uint8_t i, max;
    gps_geodetic_nt *geop;

    /*
     * collect raw message for debugging.  Eventually this will go away
     * or be put on a conditional.
     */
    gdp = (dt_gps_raw_nt *) collect_msg;
    gdp->len = DT_HDR_SIZE_GPS_RAW + SIRF_OVERHEAD + collect_length;
    gdp->dtype = DT_GPS_RAW;
    gdp->chip  = CHIP_GPS_SIRF3;
    gdp->stamp_mis = call LocalTime.get();
    call Collect.collect(collect_msg, gdp->len);

    /*
     * Look at message and see if is a geodetic.  If so process it
     */
    geop = (gps_geodetic_nt *) (&collect_msg[GPS_START_OFFSET]);
    if (geop->start != SIRF_BIN_START || geop->start_2 != SIRF_BIN_START_2) {
      call Panic.panic(PANIC_GPS, 133, geop->start, geop->start_2, 0, 0);
    }
    if (geop->len == GEODETIC_LEN && geop->mid == MID_GEODETIC)
      process_geodetic(geop);

    /*
     * Done processing, so collect any other bytes that have come in and are
     * stored in the overflow area.
     */
    atomic {
      /*
       * note: collect_nxt gets reset on first call to GPSMsg.byte_avail()
       * The only way to be here is if gps_msg_task has been posted which
       * means that on_overflow is true.  We simply need to look at collect_nxt
       * which will be > 0 if we have something that needs to be drained.
       */
      max = collect_nxt;
      on_overflow = FALSE;
      for (i = 0; i < max; i++)
	call GPSMsg.byteAvail(collect_overflow[i]); // BRK_GPS_OVR
      collect_overflow[0] = 0;
    }
    nop();
  }


  command error_t GPSMsgControl.start() {
    atomic {
      collect_state = COLLECT_START;
      on_overflow = FALSE;
      collect_overflow[0] = 0;
      return SUCCESS;
    }
  }


  command error_t GPSMsgControl.stop() {
    nop();
    return SUCCESS;
  }


  command error_t Init.init() {
    collect_overflow_full = 0;
    collect_overflow_max  = 0;
    collect_too_big = 0;
    collect_chksum_fail = 0;
    collect_proto_fail = 0;
    memset(collect_msg, 0, sizeof(collect_msg));
    call GPSMsgControl.start();
    return SUCCESS;
  }


  command void GPSMsg.reset() {
    call GPSMsgControl.start();
  }


  inline void collect_restart() {
    collect_state = COLLECT_START;
    signal GPSMsg.msgBoundary();
  }


  async command void GPSMsg.byteAvail(uint8_t byte) {
    uint16_t chksum;

    if (on_overflow) {		// BRK_GOT_CHR
      if (collect_nxt >= GPS_OVR_SIZE) {
	/*
	 * full, throw them all away.
	 */
	collect_nxt = 0;
	collect_overflow[0] = 0;
	collect_overflow_full++;
	return;
      }
      collect_overflow[collect_nxt++] = byte;
      if (collect_nxt > collect_overflow_max)
	collect_overflow_max = collect_nxt;
      return;
    }

    switch(collect_state) {
      case COLLECT_START:
	if (byte != SIRF_BIN_START)
	  return;
	collect_nxt = GPS_START_OFFSET;
	collect_msg[collect_nxt++] = byte;
	collect_state = COLLECT_START_2;
	return;

      case COLLECT_START_2:
	if (byte == SIRF_BIN_START)		// got start again.  stay
	  return;
	if (byte != SIRF_BIN_START_2) {		// not what we want.  restart
	  collect_restart();
	  return;
	}
	collect_msg[collect_nxt++] = byte;
	collect_state = COLLECT_LEN;
	return;

      case COLLECT_LEN:
	collect_length = byte << 8;		// data fields are big endian
	collect_msg[collect_nxt++] = byte;
	collect_state = COLLECT_LEN_2;
	return;

      case COLLECT_LEN_2:
	collect_length |= byte;
	collect_left = byte;
	collect_msg[collect_nxt++] = byte;
	collect_state = COLLECT_PAYLOAD;
	collect_cur_chksum = 0;
	if (collect_length >= (GPS_BUF_SIZE - GPS_OVERHEAD)) {
	  collect_too_big++;
	  collect_restart();
	  return;
	}
	return;

      case COLLECT_PAYLOAD:
	collect_msg[collect_nxt++] = byte;
	collect_cur_chksum += byte;
	collect_left--;
	if (collect_left == 0)
	  collect_state = COLLECT_CHK;
	return;

      case COLLECT_CHK:
	collect_msg[collect_nxt++] = byte;
	collect_state = COLLECT_CHK_2;
	return;

      case COLLECT_CHK_2:
	collect_msg[collect_nxt++] = byte;
	chksum = collect_msg[collect_nxt - 2] << 8 | byte;
	if (chksum != collect_cur_chksum) {
	  collect_chksum_fail++;
	  collect_restart();
	  return;
	}
	collect_state = COLLECT_END;
	return;

      case COLLECT_END:
	collect_msg[collect_nxt++] = byte;
	if (byte != SIRF_BIN_END) {
	  collect_proto_fail++;
	  collect_restart();
	  return;
	}
	collect_state = COLLECT_END_2;
	return;

      case COLLECT_END_2:
	collect_msg[collect_nxt++] = byte;
	if (byte != SIRF_BIN_END_2) {
	  collect_proto_fail++;
	  collect_restart();
	  return;
	}
	on_overflow = TRUE;
	collect_nxt = 0;
	collect_restart();
	post gps_msg_task();
	return;

      default:
	call Panic.panic(PANIC_GPS, 134, collect_state, 0, 0, 0);
	return;
    }
  }


  async command bool GPSMsg.atMsgBoundary() {
    atomic return (collect_state == COLLECT_START);
  }
}
