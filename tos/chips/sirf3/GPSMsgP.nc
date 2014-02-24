/*
 * Copyright (c) 2008, 2014: Eric B. Decker
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
#include "typed_data.h"
#include "sirf.h"
#include "gps.h"
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


gpsm_state_t gpsm_state;


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
    interface StdControl as GPSControl;
    interface Surface;
    interface LogEvent;
    interface DTSender;
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
  bool     got_fix;
  uint32_t gps_on_time;

#ifdef GPS_SHORT_COUNT
  uint8_t  short_count;
#endif

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

  void gpscontrol_started() {
#ifdef GPS_SHORT_COUNT
    short_count = GPS_SHORT_COUNT + 1;
#endif
    gpsm_state = GPSM_SHORT;
    gps_on_time = call LocalTime.get();
    call MsgTimer.startOneShot(GPS_MSG_SHORT_WINDOW);
    call GPSControl.start();
  }

  void gpscontrol_stopped() {
    gpsm_state = GPSM_DOWN;
    call MsgTimer.stop();
    call GPSControl.stop();
  }

#ifdef notdef
  task void gps_msg_control_task() {
    switch (gpsm_state) {
      default:
	call Panic.warn(PANIC_GPS, 128, gpsm_state, 0, 0, 0);
	gpscontrol_stopped();
	return;

      case GPSM_STARTING:
	gpscontrol_started();
	return;

      case GPSM_STOPPING:
	gpscontrol_stopped();
	return;
    }
  }
#endif


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
#ifdef GPS_STAY_UP
#else
    if (gpsm_state != GPSM_DOWN) {
      call Panic.warn(PANIC_GPS, 130, gpsm_state, 0, 0, 0);
      gpscontrol_stopped();
    }
#endif
    got_fix = FALSE;
    gpsm_state = GPSM_STARTING;
    gpscontrol_started();
  }

  event void Surface.submerged() {
    uint32_t t;

    t = call LocalTime.get();
    if (last_submerged && (t - last_surfaced ) < 1024)
      call Panic.warn(PANIC_GPS, 131, 0, 0, 0, 0);
    last_submerged = t;
#ifdef GPS_STAY_UP
#else
    gpsm_state = GPSM_STOPPING;
    gpscontrol_stopped();
#endif
  }


  event void MsgTimer.fired() {
    switch (gpsm_state) {
      default:
	call Panic.warn(PANIC_GPS, 132, gpsm_state, 0, 0, 0);
	gpscontrol_stopped();
	return;

      case GPSM_DOWN:
	call Panic.warn(PANIC_GPS, 133, gpsm_state, 0, 0, 0);
	gpscontrol_stopped();
	return;

      case GPSM_SHORT:
	gpsm_state = GPSM_LONG;
	call MsgTimer.startOneShot(GPS_MSG_LONG_WINDOW);
	return;

      case GPSM_LONG:
#ifdef GPS_STAY_UP
#else
	gpscontrol_stopped();
#endif
	return;
    }
  }


  /*
   * Process a nav data packet from the Sirf3.  MID 2
   */
  void process_navdata(gps_nav_data_nt *np) {

#ifdef GPS_COMM_EMIT_2
    uint8_t event_data[DT_HDR_SIZE_EVENT];
    dt_event_nt *edp;

    edp = (dt_event_nt *) &event_data;
    edp->len = DT_HDR_SIZE_EVENT;
    edp->dtype = DT_EVENT;
    edp->stamp_ms = call LocalTime.get();
    edp->ev = DT_EVENT_GPS_SATS_2;
    edp->arg = np->sats;
    call DTSender.send(event_data, DT_HDR_SIZE_EVENT);
#endif

    if (!np || np->len != NAVDATA_LEN)
      return;

    call LogEvent.logEvent(DT_EVENT_GPS_SATS_2, np->sats);
    call LogEvent.logEvent(DT_EVENT_GPSCM_STATE, (gpsc_state << 8) | gpsm_state);
  }


  /*
   * Process a clock status data packet from the Sirf3.  MID 7
   */
  void process_clockstatus(gps_clock_status_data_nt *cp) {

#ifdef GPS_COMM_EMIT_7
    uint8_t event_data[DT_HDR_SIZE_EVENT];
    dt_event_nt *edp;

    edp = (dt_event_nt *) &event_data;
    edp->len = DT_HDR_SIZE_EVENT;
    edp->dtype = DT_EVENT;
    edp->stamp_ms = call LocalTime.get();
    edp->ev = DT_EVENT_GPS_SATS_7;
    edp->arg = cp->sats;
    call DTSender.send(event_data, DT_HDR_SIZE_EVENT);
#endif

    if (!cp || cp->len != CLOCKSTATUS_LEN)
      return;

    call LogEvent.logEvent(DT_EVENT_GPS_SATS_7, cp->sats);
    call LogEvent.logEvent(DT_EVENT_GPSCM_STATE, (gpsc_state << 8) | gpsm_state);
  }


  /*
   * Process a Geodetic packet from the Sirf3.   MID 29
   */
  void process_geodetic(gps_geodetic_nt *gp) {
#ifdef GPS_COMM_EMIT_29
    uint8_t event_data[DT_HDR_SIZE_EVENT];
    dt_event_nt *edp;
#endif

    /*
     * Extract time and position data out
     */

    uint8_t gps_time_block[GPS_TIME_BLOCK_SIZE];
    uint8_t gps_pos_block[GPS_POS_BLOCK_SIZE];
    dt_gps_time_nt *timep;
    dt_gps_pos_nt *posp;
    uint32_t t, t1;

    if (!gp || gp->len != GEODETIC_LEN)
      return;

    timep = (dt_gps_time_nt*)gps_time_block;
    posp = (dt_gps_pos_nt*)gps_pos_block;

    timep->len = GPS_TIME_BLOCK_SIZE;
    timep->dtype = DT_GPS_TIME;
    timep->stamp_ms = call LocalTime.get();
    timep->chip_type = CHIP_GPS_SIRF3;
    timep->num_svs = gp->num_svs;
    timep->utc_year = gp->utc_year;
    timep->utc_month = gp->utc_month;
    timep->utc_day = gp->utc_day;
    timep->utc_hour = gp->utc_hour;
    timep->utc_min = gp->utc_min;
    timep->utc_millsec = gp->utc_sec;
    timep->clock_bias = gp->clock_bias;
    timep->clock_drift = gp->clock_drift;

    posp->len = GPS_POS_BLOCK_SIZE;
    posp->dtype = DT_GPS_POS;
    posp->stamp_ms = timep->stamp_ms;
    posp->chip_type = CHIP_GPS_SIRF3;
    posp->nav_type = gp->nav_type;
    posp->num_svs = gp->num_svs;
    posp->sats_seen = gp->sat_mask;
    posp->gps_lat = gp->lat;
    posp->gps_long = gp->lon;
    posp->ehpe = gp->ehpe;
    posp->hdop = gp->hdop;

    /*
     * Check for state change information
     */
#ifdef GPS_COMM_EMIT_29
    edp = (dt_event_nt *) &event_data;
    edp->len = DT_HDR_SIZE_EVENT;
    edp->dtype = DT_EVENT;
    edp->stamp_ms = call LocalTime.get();
    edp->ev = DT_EVENT_GPS_SATS_29;
    edp->arg = gp->num_svs;
    call DTSender.send(event_data, DT_HDR_SIZE_EVENT);
#endif
    call LogEvent.logEvent(DT_EVENT_GPS_SATS_29, gp->num_svs);
    call LogEvent.logEvent(DT_EVENT_GPSCM_STATE, (gpsc_state << 8) | gpsm_state);

    if (gp->nav_valid == 0) {
      if (!got_fix) {
	got_fix = TRUE;
	t1 = call LocalTime.get();
	t = t1 - gps_on_time;
	if (t > 0xffff) {
	  nop();
	  call Panic.warn(PANIC_GPS, 0xff, (gps_on_time >> 16), (gps_on_time & 0xffff), (t >> 16), (t & 0xffff));
	  call Panic.warn(PANIC_GPS, 0xfe, (t1 >> 16), (t1 & 0xffff), 0, 0);
	}
	call LogEvent.logEvent(DT_EVENT_GPS_FIRST, ( t > 0xffff ? 0xffff : t));
      }
      call Collect.collect(gps_time_block, GPS_TIME_BLOCK_SIZE);
      call Collect.collect(gps_pos_block, GPS_POS_BLOCK_SIZE);

      /*
       * overdetermined.  For now if we are in the SHORT window
       * then power down because we got the fix.
       */
      if (gpsm_state == GPSM_SHORT) {
	call LogEvent.logEvent(DT_EVENT_GPS_FAST,0);
#ifdef GPS_NO_SHORT
#else

#ifdef GPS_STAY_UP
#else

#ifdef GPS_SHORT_COUNT
	if (--short_count > 0)
	  return;
#endif
	gpsm_state = GPSM_STOPPING;
	gpscontrol_stopped();
#endif

#endif
	return;
      }
    }
  }


  task void gps_msg_task() {
    dt_gps_raw_nt *gdp;
    uint8_t i, max;
    gps_geodetic_nt *gp;

    /*
     * collect raw message for debugging.  Eventually this will go away
     * or be put on a conditional.
     */
    gdp = (dt_gps_raw_nt *) collect_msg;
    gdp->len = DT_HDR_SIZE_GPS_RAW + SIRF_OVERHEAD + collect_length;
    gdp->dtype = DT_GPS_RAW;
    gdp->chip  = CHIP_GPS_SIRF3;
    gdp->stamp_ms = call LocalTime.get();
    call Collect.collect(collect_msg, gdp->len);

    /*
     * Look at message and see if it is a geodetic.  If so process it
     */
    gp = (gps_geodetic_nt *) (&collect_msg[GPS_START_OFFSET]);
    if (gp->start1 != SIRF_BIN_START || gp->start2 != SIRF_BIN_START_2) {
      call Panic.warn(PANIC_GPS, 134, gp->start1, gp->start2, 0, 0);
    }
    switch (gp->id) {
      case MID_GEODETIC:
	process_geodetic(gp);
	break;
      case MID_NAVDATA:
	process_navdata((void *) gp);
	break;
      case MID_CLOCKSTATUS:
	process_clockstatus((void *) gp);
	break;
      default:
	break;
    }

    gdp->len = 0;			/* debug cookies */
    gdp->data[0] = 0;
    gdp->data[1] = 0;

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
    return SUCCESS;
  }


  command error_t Init.init() {
    gpsm_state = GPSM_DOWN;
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
	call Panic.warn(PANIC_GPS, 135, collect_state, 0, 0, 0);
	collect_restart();
	return;
    }
  }


  async command bool GPSMsg.atMsgBoundary() {
    atomic return (collect_state == COLLECT_START);
  }

  /*
   * GPS status messages are sent via DTSender as SNS_ID 0 (same as sync and restart
   * messages.  That means that any send_data_done signal for SNS_ID 0 will also come
   * here.
   */
  event void DTSender.sendDone(error_t err) {}
}
