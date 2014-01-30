/*
 * Copyright (c) 2012 Eric B. Decker
 * All rights reserved.
 *
 * @author Eric B. Decker (cire831@gmail.com)
 * @date 04 June 2012
 *
 * Handle an incoming SIRF binary byte stream assembling it into
 * protocol messages and then process the ones we are interested in.
 *
 * A single buffer is used which assumes that the processing occurs
 * fairly quickly.  In our case we copy the data over to the data
 * collector.
 *
 * There is room left at the front of the msg buffer to put the
 * collector header.
 *
 * Unlike, the SIRF3 implementation (which is interrupt driven async
 * serial), the ORG4472 transfers data via SPI which is strictly
 * master/slave and not run off interrupts.  The SPI interface is also
 * run significantly faster than the serial connection... (4Mbps vs.
 * 57600 bps).  This yields significantly lower per packet transient
 * times and makes it feasible to transfer packets directly and in line.
 */

#include "panic.h"
#include "typed_data.h"
#include "sirf.h"
#include "gps.h"
#include "gps_msg.h"

/*
 * gbuf is for eavesdropping.   The ORG4472 is SPI based with fifos and
 * idle bytes.  The protocol is binary and so we need to know if we are
 * seeing idle bytes inside packets or outside (they should only show up
 * outside packets).  The only piece that knows whether we are in a
 * packet or not is the packet processor (GPSMsgP).
 *
 * m_times is used for instrumentating and capturing packet arrival times.
 */

//#define GPS_EAVES_SIZE 12288
#define GPS_EAVES_SIZE 2048
#define M_TIMES_SIZE   256

uint8_t gbuf[GPS_EAVES_SIZE];
uint16_t g_idx;
uint32_t m_times[M_TIMES_SIZE];
uint16_t m_idx;
bool     gbuf_idle;

/*
 * GPS Message Collector states.  Where in the message is the state machine.  Used
 * when collecting messages.   Force COLLECT_START to be 0 so it gets initilized
 * by the bss initilizer and we don't have to do it.
 */
typedef enum {
  COLLECT_START = 0,
  COLLECT_START_2,
  COLLECT_LEN,
  COLLECT_LEN_2,
  COLLECT_PAYLOAD,
  COLLECT_CHK,
  COLLECT_CHK_2,
  COLLECT_END,
  COLLECT_END_2,
  COLLECT_BUSY,				/* buffer is being processed. */
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


/* GPSM -> gps msg */
gpsm_state_t gpsm_state;


module GPSMsgP {
  provides {
    interface Init;
    interface StdControl as GPSMsgControl;
    interface GPSMsgS;
  }
  uses {
    interface Panic;
    interface LocalTime<TMilli>;
    interface Timer<TMilli> as MsgTimer;
    interface StdControl as GPSControl;
//    interface Collect;
//    interface Surface;
//    interface LogEvent;
//    interface DTSender;
  }
}

implementation {

  collect_state_t collect_state;		// message collection state
  norace uint16_t collect_length;		// length of payload
  uint16_t        collect_cur_chksum;		// running chksum of payload

  uint8_t  collect_msg[GPS_BUF_SIZE];
  uint8_t  collect_nxt;				// where we are in the buffer
  uint8_t  collect_left;			// working copy
  bool     got_fix;
  uint32_t gps_on_time;

#ifdef GPS_SHORT_COUNT
  uint8_t  short_count;
#endif

  /*
   * Error counters
   */
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


#ifdef notdef
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
#endif


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
    edp->stamp_mis = call LocalTime.get();
    edp->ev = DT_EVENT_GPS_SATS_2;
    edp->arg = np->sats;
//  call DTSender.send(event_data, DT_HDR_SIZE_EVENT);
#endif

    if (!np || np->len != NAVDATA_LEN)
      return;

//  call LogEvent.logEvent(DT_EVENT_GPS_SATS_2, np->sats);
//  call LogEvent.logEvent(DT_EVENT_GPSCM_STATE, (gpsc_state << 8) | gpsm_state);
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
    edp->stamp_mis = call LocalTime.get();
    edp->ev = DT_EVENT_GPS_SATS_7;
    edp->arg = cp->sats;
//  call DTSender.send(event_data, DT_HDR_SIZE_EVENT);
#endif

    if (!cp || cp->len != CLOCKSTATUS_LEN)
      return;

//  call LogEvent.logEvent(DT_EVENT_GPS_SATS_7, cp->sats);
//  call LogEvent.logEvent(DT_EVENT_GPSCM_STATE, (gpsc_state << 8) | gpsm_state);
  }


  /*
   * Process a Geodetic packet from the Sirf3.   MID 41 (0x29)
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
    timep->stamp_mis = call LocalTime.get();
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
    posp->stamp_mis = timep->stamp_mis;
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
    edp->stamp_mis = call LocalTime.get();
    edp->ev = DT_EVENT_GPS_SATS_29;
    edp->arg = gp->num_svs;
//  call DTSender.send(event_data, DT_HDR_SIZE_EVENT);
#endif
//  call LogEvent.logEvent(DT_EVENT_GPS_SATS_29, gp->num_svs);
//  call LogEvent.logEvent(DT_EVENT_GPSCM_STATE, (gpsc_state << 8) | gpsm_state);

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
//	call LogEvent.logEvent(DT_EVENT_GPS_FIRST, ( t > 0xffff ? 0xffff : t));
      }
//    call Collect.collect(gps_time_block, GPS_TIME_BLOCK_SIZE);
//    call Collect.collect(gps_pos_block, GPS_POS_BLOCK_SIZE);

      /*
       * overdetermined.  For now if we are in the SHORT window
       * then power down because we got the fix.
       */
      if (gpsm_state == GPSM_SHORT) {
//	call LogEvent.logEvent(DT_EVENT_GPS_FAST,0);
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
    gps_geodetic_nt *gp;

    /*
     * collect raw message for debugging.  Eventually this will go away
     * or be put on a conditional.
     */
    gdp = (dt_gps_raw_nt *) collect_msg;
    gdp->len = DT_HDR_SIZE_GPS_RAW + SIRF_OVERHEAD + collect_length;
    gdp->dtype = DT_GPS_RAW;
    gdp->chip  = CHIP_GPS_ORG4472;
    gdp->stamp_mis = call LocalTime.get();
//  call Collect.collect(collect_msg, gdp->len);

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
    collect_state = COLLECT_START;
    signal GPSMsgS.resume();	/* tell source to fire up data stream again... */
  }


  command error_t GPSMsgControl.start() {
    collect_state = COLLECT_START;
    return SUCCESS;
  }


  command error_t GPSMsgControl.stop() {
    return SUCCESS;
  }


  command error_t Init.init() {
    gpsm_state = GPSM_DOWN;
    memset(gbuf, 0, GPS_EAVES_SIZE);
    call GPSMsgControl.start();
    return SUCCESS;
  }


  command void GPSMsgS.reset() {
    call GPSMsgControl.start();
  }


  command uint16_t GPSMsgS.eavesIndex() {
    return g_idx;
  }


  inline void collect_restart() {
    collect_state = COLLECT_START;
    gbuf_idle = FALSE;
  }


  void addEavesDrop(uint8_t byte) {
    do {
      /*
       * If we are between packets (COLLECT_START), then we only
       * capture the first idle byte seen.  Otherwise capture
       * any bytes we see.
       */
      if (byte == SIRF_SPI_IDLE || byte == SIRF_SPI_IDLE_2) {
	if (gbuf_idle &&
	    (collect_state == COLLECT_START || collect_state == COLLECT_BUSY))
	  break;
	gbuf_idle = TRUE;
//	gbuf_idle = FALSE;
      } else gbuf_idle = FALSE;
      gbuf[g_idx++] = byte;
      if (g_idx >= GPS_EAVES_SIZE) {
	g_idx = 0;
	nop();
      }
      if (byte == '$' || byte == SIRF_BIN_START
//	  || (byte >= 0xc0 && byte <= 0xcf)
	  ) {		// markers
	m_times[m_idx] = call LocalTime.get();
	m_idx++;
	if (m_idx >= M_TIMES_SIZE) {
	  m_idx = 0;
	  nop();
	}
      }
    } while (0);
  }


  /*
   * byteAvail: new data stream byte is available
   *
   * process a new byte, apply to protocol engine, collect into message
   * buffer.  If a complete message has been collected, wake the msg
   * processor task.
   *
   * returns FALSE if the byte can't be processed (collection buffer is busy).
   * returns TRUE if the byte has been consummed.
   */
  command bool GPSMsgS.byteAvail(uint8_t byte) {
    uint16_t chksum;

    if (collect_state == COLLECT_BUSY)
      return FALSE;

    addEavesDrop(byte);
    switch(collect_state) {
      case COLLECT_START:
	if (byte != SIRF_BIN_START)
	  break;
	collect_nxt = GPS_START_OFFSET;
	collect_msg[collect_nxt++] = byte;
	collect_state = COLLECT_START_2;
	break;

      case COLLECT_START_2:
	if (byte == SIRF_BIN_START)		// got start again.  stay
	  break;
	if (byte != SIRF_BIN_START_2) {		// not what we want.  restart
	  collect_restart();
	  break;
	}
	collect_msg[collect_nxt++] = byte;
	collect_state = COLLECT_LEN;
	break;

      case COLLECT_LEN:
	collect_length = byte << 8;		// data fields are big endian
	collect_msg[collect_nxt++] = byte;
	collect_state = COLLECT_LEN_2;
	break;

      case COLLECT_LEN_2:
	collect_length |= byte;
	collect_left = byte;
	collect_msg[collect_nxt++] = byte;
	collect_state = COLLECT_PAYLOAD;
	collect_cur_chksum = 0;
	if (collect_length >= (GPS_BUF_SIZE - GPS_OVERHEAD)) {
	  collect_too_big++;
	  collect_restart();
	  break;
	}
	break;

      case COLLECT_PAYLOAD:
	collect_msg[collect_nxt++] = byte;
	collect_cur_chksum += byte;
	collect_left--;
	if (collect_left == 0)
	  collect_state = COLLECT_CHK;
	break;

      case COLLECT_CHK:
	collect_msg[collect_nxt++] = byte;
	collect_state = COLLECT_CHK_2;
	break;

      case COLLECT_CHK_2:
	collect_msg[collect_nxt++] = byte;
	chksum = collect_msg[collect_nxt - 2] << 8 | byte;
	if (chksum != collect_cur_chksum) {
	  collect_chksum_fail++;
	  collect_restart();
	  break;
	}
	collect_state = COLLECT_END;
	break;

      case COLLECT_END:
	collect_msg[collect_nxt++] = byte;
	if (byte != SIRF_BIN_END) {
	  collect_proto_fail++;
	  collect_restart();
	  break;
	}
	collect_state = COLLECT_END_2;
	break;

      case COLLECT_END_2:
	collect_msg[collect_nxt++] = byte;
	if (byte != SIRF_BIN_END_2) {
	  collect_proto_fail++;
	  collect_restart();
	  break;
	}
	collect_nxt = 0;
	collect_state = COLLECT_BUSY;
	post gps_msg_task();
	break;

      default:
	call Panic.warn(PANIC_GPS, 135, collect_state, 0, 0, 0);
	collect_restart();
	break;
    }
    return TRUE;
  }


  command uint16_t GPSMsgS.processBuffer(uint8_t *buf, uint16_t len) {
    uint16_t i;

    for (i = 0; i < len; i++ ) {
      if (call GPSMsgS.byteAvail(buf[i]) == FALSE)
	return i;
    }
    return i;
  }


  command bool GPSMsgS.bufferAvail() {
    return (collect_state != COLLECT_BUSY);
  }


  command bool GPSMsgS.atMsgBoundary() {
    switch (collect_state) {
      case COLLECT_START:
	return TRUE;
      case COLLECT_BUSY:
	return TRUE;
      default:
	return FALSE;
    }
  }

  command void GPSMsgS.eavesDrop(uint8_t byte) {
    addEavesDrop(byte);
  }


  command void GPSMsgS.eavesDropBuffer(uint8_t *buf, uint16_t len) {
    uint16_t i;

    for (i = 0; i < len; i++)
      addEavesDrop(buf[i]);
  }


#ifdef notdef
  /*
   * GPS status messages are sent via DTSender as SNS_ID 0 (same as sync and restart
   * messages.  That means that any send_data_done signal for SNS_ID 0 will also come
   * here.
   */
  event void DTSender.sendDone(error_t err) {}
#endif

//  async event void Panic.hook() { }
}
