/*
 * Copyright (c) 2012, 2014 Eric B. Decker
 * All rights reserved.
 *
 * @author Eric B. Decker (cire831@gmail.com)
 * @date 23 May 2012
 *
 * org4472 driver, dedicated 5438 usci spi port
 * based on dedicated 2618 usci uart port sirf3 driver.
 *
 * GPSC -> Gps Control
 */

#include "gps.h"
#include "sirf.h"

#include "platform_panic.h"
#include "platform_spi_org4472.h"

/*
 * The ORG4472 GPS module is interfaced using SPI at 4MHz.  It can communicate
 * using NMEA or OSP (One Socket Protocol), SirfBin superset.  The default
 * factory setting is to communicate using NMEA.
 *
 * Since we are communicating using SPI and the gps chip is a SPI slave, it
 * can't send us unsolicited messages.   We always have to be talking to
 * the chip for it to talk to us.
 *
 * On initial power on (system power up), the gps can take anywhere from 300ms upwards to
 * 5 secs (in cold conditions) to power up the RTC module.  (Info from the Fastrax, org
 * data sheet).  Normally, we keep powered applied so this shouldn't be an issue.  Normal
 * turn on (initiated by on_off toggle), takes at least 74ms (observed).   Documentation says
 * 20ms but that is wrong.  We pulse on_off for 100 ms to bring the chip out of hibernate
 * so that should cover it.   We will see initial turn on problems (given the RTC takes
 * 300ms upwards to 5 seconds to turn on).   Unclear if this effects the operation of
 * the SPI h/w.   We need have the wakeup state machine handle this.   If the initial attempt
 * to communicate fails, then take CS down, possibly reset, and delay longer.
 *
 * When the GPS is turned on, we first assume that it is has preserved its
 * running configuration which is OSP/SirfBin.  We look for the OkToSend (bin 18).
 * If we lost power, the chip will revert to NMEA and OkToSend will be the nmea PSRF150.
 * message.   We should initially get one or the other.
 *
 * The driver needs to function so as to keep the gps TX fifo (gps to cpu) empty.
 * When the gps is first powered on it will be configured to be sending messages
 * periodically.   If we need to switch from NMEA we also turn off all periodic
 * messages and only get information via direct polling.   The chip is a SPI slave
 * and so doing async I/O into the fifos is stupid.
 *
 * Questions questions questions...
 *
 * 1) Currently we request the SPI which configures it once at the beginning via SoftwareInit.
 *    Does this have power implications?   Revisit later.   May need to deconfigure when
 *    down/off to turn off the SPI hardware....   Does having the SPI configured but not
 *    clocking cost power?  Probably not.   The SPI only clocks when bytes are being moved.
 *    This refers to the SPI h/w on the cpu (not the gps chip).
 */

typedef enum {
  GPSC_OFF  = 0,
  GPSC_FAIL = 1,
  GPSC_PULSE_ON,			/* turning on */

  GPSC_RECONFIG_WAIT,			// initial wait when switching over

  GPSC_POLL_NAV,			// just turned on, see how we are doing.

  GPSC_EOS_WAIT,			// special, wait before we can send.
  GPSC_SENDING,				// sending commands we want to force

  GPSC_SHUTDOWN_WAIT,			// waiting to see if shutdown message worked
  GPSC_PULSE_OFF,			// trying pulse to turn off
  GPSC_PULSE_OFF_WAIT,			// give it time.
  GPSC_RESET_PULSE,
  GPSC_RESET_WAIT,

  GPSC_ON,
  GPSC_BACK_TO_NMEA,
} gpsc_state_t;


typedef enum {
  GPSW_NONE =			0,
  GPSW_TIMER,
  GPSW_RXBYTE,
  GPSW_CONFIG_TASK,
  GPSW_SEND_DONE,
  GPSW_MSG_BOUNDARY,
  GPSW_START,
  GPSW_STOP,
} gps_where_t;


#ifdef GPS_LOG_EVENTS

typedef struct {
  uint32_t     ts;
  gpsc_state_t gc_state;
  gps_where_t  where;
  uint16_t     g_idx;
} gps_event_t;


#define GPS_MAX_EVENTS 32

gps_event_t g_evs[GPS_MAX_EVENTS];
uint8_t g_nev;			// next gps event

#endif		// GPS_LOG_EVENTS


uint16_t wait_time = 500;

gpsc_state_t	    gpsc_state;			// low level collector state

/* instrumentation */
uint32_t		    gpsc_boot_time;		// time it took to boot.
uint32_t		    gpsc_cycle_time;		// time last cycle took
uint32_t		    gpsc_max_cycle;		// longest cycle time.


/*
 * control structure for incoming bytes from the gps.
 * Blocks of data from the gps are variable so we need both
 * an index and remaining counts.
 */
typedef struct {
  uint16_t index;			/* where the next char is */
  uint16_t remaining;			/* how many are left */
  uint8_t buf[BUF_INCOMING_SIZE];
} inbuf_t;

inbuf_t incoming;			/* incoming bytes from gps */


module ORG4472P {
  provides {
    interface Init;
    interface StdControl as GPSControl;
    interface Msp430UsciConfigure;
//    interface Boot as GPSBoot;
  }
  uses {
    interface Timer<TMilli> as GPSTimer;
    interface LocalTime<TMilli>;
    interface Hpl_MM_hw as HW;
    interface Panic;
    interface SpiBlock;
    interface SpiByte;
    interface Resource as SpiResource;

    interface GPSMsgS;
    interface StdControl as GPSMsgControl;
//    interface Trace;
//    interface LogEvent;
//    interface Boot;
  }
}


implementation {

  uint32_t	t_gps_pwr_on;
  uint8_t	gpsc_reconfig_trys;
  bool		gpsc_operational;		// if 0 then booting, do special stuff

  void gpsc_log_state(gpsc_state_t next_state, gps_where_t where) {
#ifdef GPS_LOG_EVENTS
    uint8_t idx;

    atomic {
      idx = g_nev++;
      if (g_nev >= GPS_MAX_EVENTS)
	g_nev = 0;
      g_evs[idx].ts = call LocalTime.get();
      g_evs[idx].gc_state = next_state;
      g_evs[idx].where = where;
      g_evs[idx].g_idx = call GPSMsgS.eavesIndex();
    }
#endif
  }

  void gpsc_change_state(gpsc_state_t next_state, gps_where_t where) {
    gpsc_log_state(next_state, where);
    gpsc_state = next_state;
  }

  void gps_panic_warn(uint8_t where, uint16_t p) {
    call Panic.warn(PANIC_GPS, where, p, 0, 0, 0);
  }

  void gps_panic(uint8_t where, uint16_t p) {
    call Panic.panic(PANIC_GPS, where, p, 0, 0, 0);
  }


#ifdef notdef
  /* add NMEA checksum to a possibly  *-terminated sentence */
  void nmea_add_checksum(uint8_t *sentence) {
    uint8_t sum = 0;
    uint8_t c, *p = sentence;

    if (*p == '$') {
      p++;
      while ( ((c = *p) != '*') && (c != '\0')) {
	sum ^= c;
	p++;
      }
      *p++ = '*';
      c = sum >> 4;
      if (c > 9)
	*p++ = c + 0x40;
      else
	*p++ = c + 0x30;
      c = sum & 0x0f;
      if (c > 9)
	*p++ = c + 0x37;
      else
	*p++ = c + 0x30;
      *p++ = '\r';
      *p++ = '\n';
    }
  }

  void sirf_bin_add_checksum(uint8_t *buf) {
    uint8_t *bp;
    uint16_t n, sum, len;

    sum = 0;
    len = buf[2] << 8 | buf[3];
    bp = &buf[4];
    for (n = 0; n < len; n++)
      sum += bp[n];
    bp[n] = (sum >> 8) & 0x7f;
    bp[n+1] = (sum & 0xff);
  }
#endif


  /*
   * gps_send_receive
   *
   * send a block of data to the gps, receive return data
   * set incoming data structures appropriately to reflect
   * how much data is received.
   */
  void gps_send_receive(const uint8_t *buf, uint16_t size) {
    if (incoming.remaining)
      gps_panic_warn(1, incoming.remaining);
    call SpiBlock.transfer((uint8_t *) buf, incoming.buf, size);
    incoming.index = 0;
    incoming.remaining = size;
  }


  /*
   * checkIdle
   *
   * Scan the remainder of the incoming buffer for idles.
   *
   * return:	TRUE	nothing remains in the buffer to be processed.
   *		FALSE	buffer has reasonable stuff in it.   process.
   *
   * Update inbuf control structures to jump over any idles we've encountered.
   *
   * The ORG has a two byte idle sequence (not completely sure of the
   * symantics, seems overly complex, but it is what we've got).
   *
   * The IDLE symantics is rather ugly.  But it is what we've got.
   * We are looking for two bytes next to each other.   Either A7B4 or
   * B4A7.   And then repeats.   We don't want to find individual instances
   * of either idle byte as that could be part of the data.  Be
   * paranoid although it probably doesn't matter because of packetization.
   */
  
  bool checkIdle() {
    uint8_t b0, b1;
    uint8_t *ptr;
    uint16_t remaining, index;

    index = incoming.index;
    remaining = incoming.remaining;
    if ((index > BUF_INCOMING_SIZE) || (remaining > BUF_INCOMING_SIZE)) {
      call Panic.warn(PANIC_GPS, 2, index, remaining, 0, 0);
      incoming.index = 0;
      incoming.remaining = 0;
      return TRUE;
    }
    if (!remaining)
      return TRUE;
    ptr = incoming.buf;
    b0 = ptr[index];
    if (b0 == SIRF_SPI_IDLE)
      b1 = SIRF_SPI_IDLE_2;
    else if (b0 == SIRF_SPI_IDLE_2)
      b1 = SIRF_SPI_IDLE;
    else
      return FALSE;
    while (remaining) {
      if (remaining >= 2) {
	if (ptr[index] != b0)
	  break;
	index++; remaining--;
	if (ptr[index] != b1)
	  break;
	index++; remaining--;
      } else {
	/* remaining 1 */
	if (ptr[index] != b0)
	  break;
	index++; remaining--;
      }
    }
    incoming.index = index;
    incoming.remaining = remaining;
    if (remaining)
      return FALSE;
    return TRUE;
  }


  /*
   * gps_mark
   *
   * mark the eavesdrop buffer...
   */
  void gps_mark(uint8_t m) {
    uint8_t b[1];

    b[0] = m;
    call GPSMsgS.eavesDropBuffer(b, 1);
  }


  /*
   * gps_drain
   *
   * drain the gps outbound fifo, discard any packets.
   *
   * used to quiesce the fifo which seems to be necessary to
   * shut the beasty down.
   */
  void gps_drain(uint16_t limit, bool pull) {
    uint16_t b_count;

    if (limit == 0)
      limit = 2047;
    b_count = 0;
    call HW.gps_set_cs();
    while (1) {
      incoming.remaining = 0;
      gps_send_receive(osp_idle_block, BUF_INCOMING_SIZE);
      call GPSMsgS.eavesDropBuffer(incoming.buf, BUF_INCOMING_SIZE);
      if (!pull && checkIdle())
	break;
      b_count += BUF_INCOMING_SIZE;
      if (b_count > limit)
	break;
    }
    call HW.gps_clr_cs();
    incoming.remaining = 0;
    if (pull)				/* if pulling, then we always hit max b_count */
      return;				/* never panic. */
    if (limit >= 2047 && b_count > limit)
      gps_panic_warn(3, b_count);
  }


  /*
   * shut down gps.
   */
  void control_stop() {
    call GPSTimer.stop();
//    call LogEvent.logEvent(DT_EVENT_GPS_OFF, 0);
    gpsc_change_state(GPSC_OFF, GPSW_STOP);
  }


  /*
   * gps_config_task: Handle gps configuration requirements.
   *
   * checking operation and changing configuration as needed.
   * manipulation of timer operations as needed.
   */
  task void gps_config_task() {
    gpsc_state_t cur_gps_state;
    uint16_t count;

    cur_gps_state = gpsc_state;
    gpsc_change_state(cur_gps_state, GPSW_CONFIG_TASK);
    switch (cur_gps_state) {
      default:
      case GPSC_FAIL:
	gps_panic(5, cur_gps_state);
	return;

      case GPSC_POLL_NAV:
	call GPSTimer.startOneShot(2000);
	return;

#ifdef notdef
	gps_send_receive(osp_send_sw_ver, sizeof(osp_send_sw_ver));
	call GPSMsgS.eavesDropBuffer(&incoming.buf[incoming.index], incoming.remaining);
	incoming.remaining = 0;
//	while (1) {
//	  gps_drain(0, 0);
//	}
	call HW.gps_clr_cs();
	gpsc_change_state(GPSC_ON, GPSW_CONFIG_TASK);
	return;
#endif

      case GPSC_EOS_WAIT:
	return;

#ifdef notdef
      case GPSC_FINISH:
	gpsc_operational = 1;
	gpsc_boot_time = call LocalTime.get() - t_gps_pwr_on;
//	call LogEvent.logEvent(DT_EVENT_GPS_BOOT_TIME, (uint16_t) gpsc_boot_time);
	return;
#endif

      case GPSC_ON:
	call GPSTimer.stop();
	return;
    }
  }


  async command const msp430_usci_config_t *Msp430UsciConfigure.getConfiguration() {
    return &org4472_spi_config;
  }


  command error_t Init.init() {
    /* gpsc_state is set to GPSC_OFF (0) by ram initializer */
    gpsc_reconfig_trys = MAX_GPS_RECONFIG_TRYS;
    call SpiResource.immediateRequest();
    return SUCCESS;
  }

  /*
   * Boot up the GPS.
   *
   * Start up strategy...
   *
   * ------------------------------------------------------------------------
   */

#ifdef notdef
 event void Boot.booted() {
    /*
     * First make sure the gps is down.  When booting make sure to power cycle
     * assumes init then booted.
     *
     * We set operational to 0 which changes the behaviour of the state machine
     * so it does somewhat different things on the way up.  Including sending
     * some packets to see the s/w version etc.  This will also causes the boot
     * signal to occur when the gps comes all the way up.
     */

//    call LogEvent.logEvent(DT_EVENT_GPS_BOOT,0);
    call HW.gps_off();
    gpsc_change_state(GPSC_OFF, GPSW_NONE);
    gpsc_operational = 0;
    call GPSControl.start();
  }
#endif


  /*
   * Start GPS.
   *
   * This is what is normally used to fire the GPS up for readings.
   * Assumes the gps has its comm settings properly setup.  SirfBin-SPI
   *
   * This is the low level state machine.  It expects to power up the gps
   * and for it to behave in a reasonable manner as observed during prototyping.
   *
   * Some thoughts...
   *
   * 1) pwr is assumed to always be on.   This initial start up condition may have
   *    to be modified for initial turn on (power coming up).   Some form of power up
   *    time out or delay (could be up to 5 secs.)   May want to do that iff initial
   *    turn on fails.
   *
   * 2) We may also want to delay getting messages from the GPS until it has had time
   *    to recapture.  (Probably not an issue.   This was an issue for the sirf3 chip
   *    because it was interrupt driven char i/o.   We are SPI running at 4 Mbps).
   *
   * 3) can we immediately throw commands requesting the navigation data we want?
   *
   * 4) can we send commands back to back?
   *
   * 5) is it reliable?
   *
   * 6) would it be better to sequence?
   *
   * Dedicated h/w.  immediateRequest.   Should we switch it over to dedicated?
   */

  command error_t GPSControl.start() {
    if (gpsc_state != GPSC_OFF) {
      gps_panic_warn(9, gpsc_state);
      return FAIL;
    }

    if (call HW.gps_awake()) {
      /*
       * shouldn't be awake.   If so, jump forward in the state machine
       * and make sure we can talk to the gps.
       */
      gps_panic_warn(10, call HW.gps_awake());
      gpsc_change_state(GPSC_POLL_NAV, GPSW_START);
      post gps_config_task();
      return SUCCESS;
    }

    /*
     * not awake (which is what we expect).   So kick the on_off pulse
     * and wake the critter up.
     */
    t_gps_pwr_on = call LocalTime.get();
    call GPSMsgControl.start();
    gpsc_change_state(GPSC_PULSE_ON, GPSW_START);
    call GPSTimer.startOneShot(DT_GPS_ON_OFF_PULSE_WIDTH);
    call HW.gps_set_on_off();
    return SUCCESS;

//    call LogEvent.logEvent(DT_EVENT_GPS_START, 0);
  }


  /*
   * Stop.
   *
   * Stop all GPS activity.
   */
  command error_t GPSControl.stop() {
//    if (gpsc_state == GPSC_OFF) {
      gps_panic_warn(110, gpsc_state);
//      return EOFF;
//    }
    if (!call HW.gps_awake()) {
      gps_panic_warn(11, call HW.gps_awake());
      gpsc_change_state(GPSC_OFF, GPSW_STOP);
      return EOFF;
    }
    gpsc_change_state(GPSC_SHUTDOWN_WAIT, GPSW_STOP);
    gps_mark(0xc8);
    gps_drain(0, 1);			/* known state */
    gps_drain(0, 1);			/* known state */
    gps_drain(0, 1);			/* known state */
    gps_drain(0, 1);			/* known state */
    call HW.gps_set_cs();
    gps_mark(0xc9);
    gps_send_receive(osp_shutdown, sizeof(osp_shutdown));
    call GPSMsgS.eavesDropBuffer(&incoming.buf[incoming.index], incoming.remaining);
    incoming.remaining = 0;
    call HW.gps_clr_cs();
    call GPSTimer.startOneShot(1000);	/* give it roughly 1 sec */
    gps_mark(0xca);
    gps_drain(0, 0);
    return SUCCESS;

#ifdef notdef
    call HW.gps_set_on_off();
    call GPSTimer.startOneShot(DT_GPS_ON_OFF_PULSE_WIDTH);
#endif
  }


  event void GPSTimer.fired() {
    switch (gpsc_state) {
      default:
      case GPSC_FAIL:
      case GPSC_OFF:
	/* shouldn't be any timer running in this state... */
	gps_panic(12, gpsc_state);
	nop();
	return;

      case GPSC_PULSE_ON:
	call HW.gps_clr_on_off();
	if (!call HW.gps_awake()) {
	  gps_panic(13, gpsc_state);
	  nop();
	  gpsc_change_state(GPSC_FAIL, GPSW_TIMER);
	  return;
	}

	/*
	 * We should have the 1st message after coming out of hibernate.
	 * The expected 1st message is OkToSend (either NMEA or SirfBin
	 * variety).  If NMEA, we want to reconfigure.
	 *
	 * We have observed that immediately after the PulseOn (100ms after
	 * sending on_off high) we should have an OkToSend, either flavor.
	 *
	 * Check which flavor and change state accordingly.
	 */

	call HW.gps_set_cs();
	gps_send_receive(osp_idle_block, BUF_INCOMING_SIZE);
	call GPSMsgS.eavesDropBuffer(&incoming.buf[incoming.index], incoming.remaining);
	incoming.remaining = 0;			// throw current away
	call HW.gps_clr_cs();

	if (memcmp(incoming.buf, nmea_oktosend, sizeof(nmea_oktosend)) == 0) {
	  /*
	   * looks like nema, reconfigure
	   *
	   * observed behaviour, we've seen the nmea oktostart and we now
	   * send the nmea_go_sirf_bin.  And what we get back is idles, so
	   * we just throw the incoming data away.   From observations, we
	   * also need to wait awile after telling the chip to switch over
	   * to sirfbin.
	   */
	  gps_mark(0xc0);
	  call HW.gps_set_cs();
	  gps_send_receive(nmea_go_sirf_bin, sizeof(nmea_go_sirf_bin));
	  call GPSMsgS.eavesDropBuffer(&incoming.buf[incoming.index], incoming.remaining);
	  incoming.remaining = 0;
	  gps_send_receive(osp_idle_block, BUF_INCOMING_SIZE - sizeof(nmea_go_sirf_bin));
	  call GPSMsgS.eavesDropBuffer(&incoming.buf[incoming.index], incoming.remaining);
	  incoming.remaining = 0;
	  call HW.gps_clr_cs();
	  gps_mark(0xc1);

	  gpsc_change_state(GPSC_RECONFIG_WAIT, GPSW_CONFIG_TASK);
	  call GPSTimer.startOneShot(wait_time);	// wait for the switch to go.
	  return;
	} else if (memcmp(incoming.buf, osp_oktosend, sizeof(osp_oktosend)) == 0) {
	  /*
	   * already in sirfbin mode...
	   */
	  gpsc_change_state(GPSC_POLL_NAV, GPSW_CONFIG_TASK);
	  post gps_config_task();
	  return;
	} else if (incoming.buf[0] == SIRF_BIN_START) {
	  gps_panic(7, incoming.buf[0]);
	  nop();
	} else {
	  /*
	   * hem.  nothing we recognize.   panic
	   */
	  gps_panic(8, incoming.buf[0]);
	  nop();
	}

	return;

      case GPSC_RECONFIG_WAIT:
	gps_mark(0xc2);
	gps_drain(16, 1);
	gps_mark(0xc3);
	call HW.gps_set_cs();
	gps_send_receive(osp_poll_clock, sizeof(osp_poll_clock));
	call GPSMsgS.eavesDropBuffer(&incoming.buf[incoming.index], incoming.remaining);
	incoming.remaining = 0;
	gps_send_receive(osp_poll_nav, sizeof(osp_poll_nav));
	call GPSMsgS.eavesDropBuffer(&incoming.buf[incoming.index], incoming.remaining);
	incoming.remaining = 0;
	gps_send_receive(osp_send_sw_ver, sizeof(osp_send_sw_ver));
	call GPSMsgS.eavesDropBuffer(&incoming.buf[incoming.index], incoming.remaining);
	incoming.remaining = 0;
	gps_send_receive(osp_send_tracker, sizeof(osp_send_tracker));
	call GPSMsgS.eavesDropBuffer(&incoming.buf[incoming.index], incoming.remaining);
	incoming.remaining = 0;
	gps_send_receive(osp_revision_req, sizeof(osp_revision_req));
	call GPSMsgS.eavesDropBuffer(&incoming.buf[incoming.index], incoming.remaining);
	incoming.remaining = 0;
	call HW.gps_clr_cs();
	gps_mark(0xc4);
	gps_drain(0, 1);
	gps_mark(0xc5);
//	while(1) {
//	  gps_drain(0, 1);
//	}
	gpsc_change_state(GPSC_ON, GPSW_CONFIG_TASK);
	return;

      case GPSC_POLL_NAV:
	gps_mark(0xcf);
	call HW.gps_set_cs();
	gps_send_receive(osp_pwr_mode, sizeof(osp_pwr_mode));
	call GPSMsgS.eavesDropBuffer(&incoming.buf[incoming.index], incoming.remaining);
	incoming.remaining = 0;
	call HW.gps_clr_cs();

	gps_drain(0,1);

	gps_mark(0xce);
	call HW.gps_set_cs();
	gps_send_receive(osp_shutdown, sizeof(osp_shutdown));
	call GPSMsgS.eavesDropBuffer(&incoming.buf[incoming.index], incoming.remaining);
	incoming.remaining = 0;
	call HW.gps_clr_cs();

	gps_drain(0,1);

	while(1) {
	  gps_drain(0,1);
	}
	call GPSTimer.startOneShot(2000);
	return;

      case GPSC_SHUTDOWN_WAIT:
	gps_mark(0xcb);
	if (call HW.gps_awake() == 0) {
	  gpsc_change_state(GPSC_OFF, GPSW_TIMER);
	  return;
	}
	/*
	 * shutdown message didn't work, try pulsing on_off
	 */
//	gps_panic_warn(113, gpsc_state);
	gps_drain(0, 0);
	gps_mark(0xcc);
	gpsc_change_state(GPSC_PULSE_OFF, GPSW_TIMER);
	call GPSTimer.startOneShot(DT_GPS_ON_OFF_PULSE_WIDTH);
	call HW.gps_set_on_off();
	return;	
	
      case GPSC_PULSE_OFF:
	call HW.gps_clr_on_off();
	gpsc_change_state(GPSC_PULSE_OFF_WAIT, GPSW_TIMER);
	call GPSTimer.startOneShot(1000);
	return;

      case GPSC_PULSE_OFF_WAIT:
	if (call HW.gps_awake() == 0) {
	  gpsc_change_state(GPSC_OFF, GPSW_TIMER);
	  return;
	}
	gps_panic_warn(14, gpsc_state);
	gps_drain(0, 0);
	gpsc_change_state(GPSC_RESET_PULSE, GPSW_TIMER);
	call GPSTimer.startOneShot(1);
	call HW.gps_set_reset();
	return;

      case GPSC_RESET_PULSE:
	call HW.gps_clr_reset();
	gpsc_change_state(GPSC_RESET_WAIT, GPSW_TIMER);
	call GPSTimer.startOneShot(1000);
	return;

      case GPSC_RESET_WAIT:
	if (call HW.gps_awake() == 0) {
	  gpsc_change_state(GPSC_OFF, GPSW_TIMER);
	  return;
	}
	gps_panic(114, gpsc_state);
	gpsc_change_state(GPSC_OFF, GPSW_TIMER);
	return;

      case GPSC_EOS_WAIT:
	/*
	 * Being in this state says we saw the start char sequence and enough
	 * time has gone by to allow us to send commands and not have them ignored.
	 * Start sending boot commands from the list.  sendDone handles sending
	 * the next.  The receiver code handles collecting any responses.  When the
	 * last command is sent go into FINI_WAIT to finish collecting responses.
	 */
	gpsc_change_state(GPSC_SENDING, GPSW_TIMER);
	call GPSTimer.startOneShot(DT_GPS_SEND_TIME_OUT);
	return;
    }
  }

  event void GPSMsgS.resume() { }
  event void SpiResource.granted() { }

  async event void Panic.hook() { }
}
