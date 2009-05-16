/*
 * Copyright (c) 2008 Eric B. Decker
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the Stanford University nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL STANFORD
 * UNIVERSITY OR ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/**
 * @author Eric B. Decker (cire831@gmail.com)
 * @date 28 May 2008
 *
 * Reworked to use the SerialDemux multiplexed ResourceDefaultOwner
 * interface.  Instead of arbritrating for the UART1 resource we
 * arbritrate for the priviledge of being the DefaultOwner and use the
 * interface when no one else wants it.
 *
 * The logic should remain about the same.  However, note that the
 * DefaultOwner.grant won't have caused the h/w to be configured so
 * we have to do it by hand.
 *
 * Interaction strategy:
 *
 * While booting the GPS ignore other requests and camp on the h/w.
 * Once booted
 */

#include "panic.h"
#include "gps.h"
#include "sirf.h"

#ifdef notdef
uint8_t gps_speed;		// will default to 0, 57600 (1 is 4800, 2 is 115200 (if compiled in))
uint8_t ro;
uint8_t gc;
#endif

#define GPS_EAVES_SIZE 2048

uint8_t gbuf[GPS_EAVES_SIZE];
uint16_t g_idx;

#if GPS_SPEED==4800
#define GPS_OP_SERIAL_CONFIG gps_4800_serial_config
#elif GPS_SPEED==57600
#define GPS_OP_SERIAL_CONFIG gps_57600_serial_config
#else
#error "GPS_SPEED not valid (see gps.h)"
#endif

const msp430_uart_union_config_t gps_4800_serial_config = { {
  ubr:   UBR_4MHZ_4800,
  umctl: UMCTL_4MHZ_4800,
  ssel: 0x02,			// smclk selected (DCO, 4MHz)
  pena: 0,			// no parity
  pev: 0,			// no parity
  spb: 0,			// one stop bit
  clen: 1,			// 8 bit data
  listen: 0,			// no loopback
  mm: 0,			// idle-line
  ckpl: 0,			// non-inverted clock
  urxse: 0,			// start edge off
  urxeie: 1,			// error interrupt enabled
  urxwie: 0,			// rx wake up disabled
  utxe : 1,			// tx interrupt enabled
  urxe : 1			// rx interrupt enabled
} };


const msp430_uart_union_config_t gps_57600_serial_config = { {
  ubr:   UBR_4MHZ_57600,
  umctl: UMCTL_4MHZ_57600,
  ssel: 0x02,			// smclk selected (DCO, 4MHz)
  pena: 0,			// no parity
  pev: 0,			// no parity
  spb: 0,			// one stop bit
  clen: 1,			// 8 bit data
  listen: 0,			// no loopback
  mm: 0,			// idle-line
  ckpl: 0,			// non-inverted clock
  urxse: 0,			// start edge off
  urxeie: 1,			// error interrupt enabled
  urxwie: 0,			// rx wake up disabled
  utxe : 1,			// tx interrupt enabled
  urxe : 1			// rx interrupt enabled
} };


typedef enum {
  GPSC_FAIL = 1,
  GPSC_OFF,

  /*
   * When the GPS is turned on , we first assume that it is running at
   * 57600-SirfBin.
   *
   * Boot up windows are defined from when the gps is turned on (t_gps_pwr_on)
   *
   * [START_DELAY is used to have the gps powered up but the cpu is not taking any interrupts from
   * it.  This allows the CPU to be sleeping while the gps is doing its power up thing.  It takes about
   * 300ms before it starts sending bytes.  This allows things to settle down before we start looking
   * for the first byte.  The thinking behind this is to allow the GPS to actually get its fix so when
   * we start looking for gps messages we will see that it has locked.]
   *
   * START_DELAY		timer fired	HUNTING
   *                                          	(timer <- t_gps_pwr_on + hunt_window)
   *					      	(uart interrupts enabled)
   *				rx byte         (panic, interrupts should be off)
   *
   * [When in the HUNTING state, we are looking for the start sequence.  If we see back to
   * back start chars (SIRF_BIN_START, SIRF_BIN_START_2) then we complete the HUNTING state
   * and assume that we are communicating.]
   *
   * [EOS_WAIT ** extra ***: wait for the start up window to close.  When the gps first powers up
   * it takes 300ms before starting to send chars (that is when we get out of HUNT), this is the
   * gps start up stream being transmitted.  If we try to send commands to the gps during this time
   * it will be ignored.  So we define a window that must close before we send anything.  EOS_WAIT
   * denotes this state.  At the end of EOS_WAIT when futzing we can send a command to the gps
   * to see what happens (sc tells what command to send).  FINI_WAIT then waits some amount of
   * time (to collect characters) before shutting down and signalling booted.
   *
   * Approach...  look for start sequence and call it a day if seen.
   * If we see the start sequence, then just turn the thing off and signal
   * booted.   BOOT_EOS_WAIT is for screwing around.  possibly sending
   * a command.  At the end of what ever we are messing around with then
   * signal booted.
   *
   */

  GPSC_RECONFIG_4800_PWR_DOWN,		// power down
  GPSC_RECONFIG_4800_START_DELAY,	// gps power on
  GPSC_RECONFIG_4800_HUNTING,		// looking for '$', nmea start
  GPSC_RECONFIG_4800_EOS_WAIT,		// waiting for end of start
  GPSC_RECONFIG_4800_SENDING,		// waiting for send of go_sirf_bin to complete


  /*
   * If operational, then we go to ON.
   *
   * If not operational, then we are booting.  When booting we want to send a
   * message to the GPS to illicit various status packets that we then store.
   * But before we can send the message we have to wait for the End Of the Start
   * window otherwise the sent message will be ignored.
   */
  GPSC_EOS_WAIT,			// special, wait before we can send.
  GPSC_SENDING,				// sending commands we want to force
  GPSC_FINI_WAIT,
  GPSC_FINISH,

  /*
   * Normal sequencing.   GPS is assumed to be configured for SirfBin@op speed
   *
   * There is a trade off that effects how this is put together.
   *
   * On one hand, if we request and obtain the GPS prior to powering
   * the GPS will hold the h/w for a longer period of time (all of the
   * power up and any communication it needs).  This might create problems
   * for the other devices on the h/w, namely the SD and comm.
   *
   * Another approach is to power the GPS up and then request at the end of
   * the power window.  The downside is if another module has the h/w, then
   * the GPS will stay powered longer then needed.  We can protect against
   * a hog by use of a timer.
   *
   * One still wants to be careful because we need to wait enough time to get out
   * of the start up window before sending the poll command.  Otherwise the gps
   * ignores our commands.
   *
   * For the time being we use method 1 and request then power.  This way we
   * can watch the start up stream.   
   */

  GPSC_REQUESTED,			// waiting for usart ownership
  GPSC_START_DELAY,			// power on
  GPSC_HUNT_1,				// Can we see them?
  GPSC_HUNT_2,
  GPSC_ON,
  GPSC_BACK_TO_NMEA,

  /*
   * kludge for debugging release states
   */
  RS_RELEASED		= 32,
  RS_DEF_GRANTING	= 33,
  RS_OWNED		= 34,
  RS_RELEASING		= 35,
} gpsc_state_t;

typedef enum {
  GPSC_RS_RELEASED	= 32,		// released, waiting for grant
  GPSC_RS_DEF_GRANTING	= 33,		// default granting in progress.
  GPSC_RS_OWNED		= 34,		// we think we own it.
  GPSC_RS_RELEASING	= 35,		// pending release
} gpsc_release_state_t;

typedef enum {
  GPSW_NONE =			0,
  GPSW_GRANT =			1,
  GPSW_TIMER =			2,
  GPSW_RXBYTE =			3,
  GPSW_CONFIG_TASK =		4,
  GPSW_SEND_DONE =		5,
  GPSW_MSG_BOUNDARY =		6,
  GPSW_RESOURCE_REQUESTED =	7,
  GPSW_OWNER_TASK =		8,
  GPSW_START =			9,
  GPSW_STOP =			10,
  GPSW_DEF_RESOURCE_GRANT =	11,
  GPSW_DEF_REQUESTED =		12,
  GPSW_DEF_GRANT =		13,
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


norace gpsc_state_t	    gpsc_state;			// low level collector state
norace gpsc_release_state_t gpsc_release_state;		// owned or released?

/* instrumentation */
norace uint32_t             gpsc_start_hold;		// time of ownership start
norace uint32_t		    gpsc_last_hold;		// how long last time.
norace uint32_t		    gpsc_boot_hold;		// time it took to boot.
norace uint32_t		    gpsc_max_hold;		// longest hold time.


module GPSP {
  provides {
    interface Init;
    interface StdControl as GPSControl;
    interface Boot as GPSBoot;
  }
  uses {
    interface Boot;
    interface Timer<TMilli> as GPSTimer;
    interface LocalTime<TMilli>;
    interface HplMM3Adc as HW;
    interface UartStream;
    interface Panic;
    interface HplMsp430Usart as Usart;
    interface GPSMsg;
    interface StdControl as GPSMsgControl;
    interface Trace;
    interface LogEvent;

    interface Resource                as SerialDemuxResource;
    interface ResourceDefaultOwner    as SerialDefOwner;
    interface ResourceDefaultOwnerMux as MuxControl;
  }
}


implementation {

  norace uint32_t     t_gps_pwr_on;
  norace uint8_t      gpsc_reconfig_trys;
  norace bool	      gpsc_operational;		// if 0 then booting, do special stuff
         uint8_t      gpsc_request_defers;
  norace bool	      othersWaiting;

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
      g_evs[idx].g_idx = g_idx;
    }
#endif
  }

  void gpsc_change_state(gpsc_state_t next_state, gps_where_t where) {
    gpsc_log_state(next_state, where);
    gpsc_state = next_state;
  }

  void gpsc_change_release_state(gpsc_release_state_t next_state, gps_where_t where) {
    gpsc_log_state(next_state, where);
    gpsc_release_state = next_state;
  }

  void gps_warn(uint8_t where, uint16_t p) {
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
   * shut down gps.
   */
  void control_stop() {
    if (gpsc_state == GPSC_OFF) {
      gps_warn(15, gpsc_state);
      return;
    }
    if (call SerialDefOwner.isOwner())
      call Usart.disableIntr();

#ifndef GPS_LEAVE_UP
    call HW.gps_off();
#endif

    call GPSTimer.stop();
    call LogEvent.logEvent(DT_EVENT_GPS_OFF, 0);
    call GPSMsgControl.stop();
    gpsc_change_state(GPSC_OFF, GPSW_STOP);
    gpsc_change_release_state(GPSC_RS_RELEASED, GPSW_STOP);
    othersWaiting = FALSE;
    if (call SerialDemuxResource.isOwner()) {
      if (call SerialDefOwner.isOwner())
	call SerialDefOwner.release();
      call SerialDemuxResource.release();
    }
  }

  void gps_granted();

  /*
   * gps_owner_task: handle changing ownership
   */
  task void gps_owner_task() {
    gpsc_release_state_t cur_release_state;

    atomic cur_release_state = gpsc_release_state;
    switch (cur_release_state) {
      default:
      case GPSC_RS_OWNED:
      case GPSC_RS_RELEASED:
	gps_panic(18, cur_release_state);	/* why did the task get posted? */
	return;					/* nothing to do */

      case GPSC_RS_DEF_GRANTING:
	/*
	 * There is a race condition that exists between we seeing the SerialDefOwner.granted
	 * signal (where we "post gps_owner_task" and getting here.  Another user (transient)
	 * may have requested the resource.  So we need to really make sure we own the resource
	 * before granting.
	 *
	 * If someone else has gotten in then we assume we will get the resource back when
	 * they are done via a SerialDefOwner.granted signal when they are done.
	 */
	if (call SerialDefOwner.isOwner()) {
	  gpsc_change_release_state(GPSC_RS_OWNED, GPSW_OWNER_TASK);
	  call Trace.trace(T_GPS_DO_GRANT, 1, 0);
	  gps_granted();
	} else {
	  gpsc_change_release_state(GPSC_RS_RELEASED, GPSW_OWNER_TASK);
	  call Trace.trace(T_GPS_DO_DEFERRED, 1, 0);
	}
	return;

      case GPSC_RS_RELEASING:
	/*
	 * note: anytime we are going to release the h/w, the first thing that is done is
	 * disable UART interrupts.  This will prevent new character events from occuring.
	 *
	 * When the requesting user is finished, we will get a DefOwner.grant.
	 */
	gpsc_change_release_state(GPSC_RS_RELEASED, GPSW_OWNER_TASK);
	call LogEvent.logEvent(DT_EVENT_GPS_RELEASE, 0);
	call GPSMsg.reset();
	call GPSTimer.startOneShot(DT_GPS_MAX_GRANT_TO);
	if (gpsc_start_hold) {
	  gpsc_last_hold = call LocalTime.get() - gpsc_start_hold;
	  gpsc_start_hold = 0;
	  if (gpsc_last_hold) {
	    if (gpsc_last_hold > gpsc_max_hold)
	      gpsc_max_hold = gpsc_last_hold;
	    call LogEvent.logEvent(DT_EVENT_GPS_HOLD_TIME, (uint16_t) gpsc_last_hold);
	    call Trace.trace(T_GPS_HOLD_TIME, (uint16_t) gpsc_last_hold, 0);
	  }
	}
	call Trace.trace(T_GPS_RELEASED, gpsc_state, gpsc_release_state);
	call SerialDefOwner.release();
	return;
    }
  }


  /*
   * gps_config_task: Handle messing with the timer on behalf of gps reconfigurations.
   */
  task void gps_config_task() {
    gpsc_state_t cur_gps_state;

    atomic cur_gps_state = gpsc_state;
    gpsc_change_state(cur_gps_state, GPSW_CONFIG_TASK);
    switch (cur_gps_state) {
      default:
	gps_panic(1, cur_gps_state);
	return;

      case GPSC_OFF:
	call GPSTimer.stop();
	gps_warn(2, 0);
	return;

      case GPSC_RECONFIG_4800_EOS_WAIT:
	call GPSTimer.startOneShotAt(t_gps_pwr_on, DT_GPS_EOS_WAIT);
	return;

      case GPSC_EOS_WAIT:
	call GPSTimer.startOneShot(DT_GPS_EOS_WAIT);
	return;

      case GPSC_FINI_WAIT:
	call GPSTimer.startOneShot(DT_GPS_FINI_WAIT);
	return;

      case GPSC_FINISH:
	gpsc_operational = 1;
	control_stop();
	nop();				// BRK_FINISH
	gpsc_boot_hold = call LocalTime.get() - gpsc_start_hold;
	call LogEvent.logEvent(DT_EVENT_GPS_BOOT_TIME, (uint16_t) gpsc_boot_hold);
	signal GPSBoot.booted();
	return;

      case GPSC_HUNT_1:
      case GPSC_HUNT_2:
	call GPSTimer.startOneShot(DT_GPS_HUNT_LIMIT);
	return;

      case GPSC_ON:
	call GPSTimer.stop();
	return;
    }
  }

  command error_t Init.init() {
    /*
     * initilize the gps event trace buffer
     * initilize eavesdrop memory
     */
    memset(g_evs, 0, sizeof(g_evs));
    g_nev = 0;
    memset(gbuf, 0, sizeof(gbuf));
    g_idx = 0;

    gpsc_change_state(GPSC_OFF, GPSW_NONE);
    gpsc_change_release_state(GPSC_RS_RELEASED, GPSW_NONE);
    t_gps_pwr_on = 0;
    gpsc_reconfig_trys = MAX_GPS_RECONFIG_TRYS;
    gpsc_request_defers = MAX_GPS_DEFERS;
    gpsc_operational = 0;
    return SUCCESS;
  }

  /*
   * Boot up the GPS.
   *
   * Start up strategy...
   *
   * The ET-312 sirfIII module has a battery pin and pwr.  The sirf chip will
   * maintain its last configuration settings as long as the battery input has
   * a reasonable amount of juice.  The pwr pin is brought up when we need
   * to have the GPS do its thing.  When powered the GPS first spews for a while
   * with development information.  Then it settles down into issuing periodic
   * navigation results.
   *
   * If the tag runs out of power, the battery pin will no longer be supplied
   * and the GPS will revert to NMEA-4800-8N1.  This will also be the case the
   * first time we turn the beast on.  If power has been maintained the GPS will
   * be SiRFbin-<op serial>-8N1.
   *
   * It takes approximately 300ms for the GPS to power up and start sending
   * data.
   *
   * HOWEVER, sending immediately doesn't seem to work.  So the question is how
   * long do we need to wait before the GPS receiver will accept the command.
   * So before we send anything we define a start window during which we don't
   * send anything.
   *
   * If power has been maintained, the GPS will still be communicating
   * in sirfBinary at the operational serial speed (57600).  So first
   * we listen at that speed.  If we see framing or other errors we switch
   * to 4800 and switch over using the NMEA change protocol message.
   *
   * at 4800 NMEA, first char must be '$' (0x24, 36)
   * in sirfbin, first char must be 0xa0 (sop is 0xa0a2)
   *
   * How long...
   *
   * Based on the following, setting power up delay to 350 and Hunt time out to 500
   * should be fine.
   *
   * DO WE NEED TIMINGS FOR 57600?  We have switched to 57600 because we were losing
   * chars at 115200.
   *
   * gps @ 4800, uart 115200 time to first char...  when do overruns and rx errors occur.
   *	no characters received.  no errors.  got power on timeout.
   *
   * gps @ 115200, 115200, TTFC:  start up message length: 129 (time 107 mis), binary
   *	first_char = 160 (0xa0), char_count = 129, t_request = 386, t_pwr_on = 387,
   *	t_first_char = 701 (314 mis), t_last_char = 808, t_eos = 778
   *	TTS: (nmea_go_sirf_bin, 26 bytes)  3 mis
   *
   * gps @ 4800, 4800: TTFC:  start up message length: 250 chars, 724 mis, 330 from gps power on
   *	first_char = 36 '$', char_count = 250, t_request = 394, t_pwr_on = 394,
   *	t_first_char = 724 (from gps power on 330 mis), t_eos = 1702 (delta (first) 978, from pwr_on 1308 mis)
   *	TTS: (nmea_go_sirf_bin, 26 bytes) 58 mis
   *
   * gps @ 115200, uart 4800:
   *	no characters received.  no errors.  get power on timeout.
   *
   * ------------------------------------------------------------------------
   */

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

    call LogEvent.logEvent(DT_EVENT_GPS_BOOT,0);
    if (mmP5out.ser_sel == SER_SEL_GPS)
      mmP5out.ser_sel = SER_SEL_NONE;
    call HW.gps_off();
    gpsc_change_state(GPSC_OFF, GPSW_NONE);
    gpsc_operational = 0;
    call GPSControl.start();
  }


  /*
   * Start GPS.
   *
   * This is what is normally used to fire the GPS up for readings.
   * Assumes the gps has its comm settings properly setup.  SirfBin-57600
   *
   * This is the low level state machine.  It expects to power up the gps
   * and for it to behave in a reasonable manner as observed during prototyping.
   *
   * Some thoughts...
   *
   * 1) Turn the gps on.  start timer for pwr up interrupts off window.  The device
   *    won't start talking for about 300ms or so (note tinyos timers are in mis
   *    units).   We also want to give the gps enough time to recapture.
   * 2) can we immediately throw commands requesting the navigation data we want?
   * 3) can we send commands back to back?
   * 4) is it reliable?
   * 5) would it be better to sequence?
   *
   * The GPS driver is a default owner of the serial h/w.  We must first arbitrate
   * for the default ownership (SerialDemuxResource).  When granted, the gps
   * driver will become the default owner when other users of the USART h/w don't
   * want the h/w.  This allows the gps driver to listen when it owns the h/w.
   * The GPS driver will hold on to the h/w while it is receiving a message and
   * will only release at a message boundary.
   *
   * When the driver determines that it truely owns the h/w, it must handle
   * configuring the h/w when the driver knows that it has gained control.
   *
   * There are some corner cases that need to be handling during transitions.
   * When releasing the SerialDemuxResource, the gps driver still needs
   * to handle SerialDefOwner.granted events until the new def owner has
   * caused the mux control to switch to it.
   */

  command error_t GPSControl.start() {
    error_t err;

    if (gpsc_state != GPSC_OFF) {
      gps_warn(3, gpsc_state);
      return FAIL;
    }
    if (call SerialDemuxResource.isOwner())
      call SerialDemuxResource.release();
    call LogEvent.logEvent(DT_EVENT_GPS_START,0);
    gpsc_change_release_state(GPSC_RS_RELEASED, GPSW_START);
    gpsc_change_state(GPSC_REQUESTED, GPSW_START);
    call GPSMsgControl.start();
    call GPSTimer.startOneShot(DT_GPS_MAX_GRANT_TO);
    call Trace.trace(T_GPS, 0x20, 0);
    err = call SerialDemuxResource.request();
    call Trace.trace(T_GPS, 0x21, 0);
    if (err) {
      control_stop();
      gps_panic(4, err);
    }
    return err;
  }


  /*
   * Stop.
   *
   * Stop all GPS activity.
   *
   * If we have requested but not yet been granted and stop is called
   * not to worry.  When the grant occurs, our state being OFF will
   * cause an immediate release.
   */
  command error_t GPSControl.stop() {
    control_stop();
    return SUCCESS;
  }


  /*
   * This routine is called anytime the GPS is granted the actual h/w.
   * This can occur when the GPS is the default owner (owns the SerialDemuxResource)
   * and a higher priority device releases.  Or if the GPS has asked for
   * the resource, it is granted, and no one owns the underlying resource.
   */
  void gps_granted() {
    gpsc_start_hold = call LocalTime.get();
    othersWaiting = FALSE;
    call LogEvent.logEvent(DT_EVENT_GPS_GRANT, gpsc_state);
    mmP5out.ser_sel = SER_SEL_GPS;
    call Usart.setModeUart((msp430_uart_union_config_t *) &GPS_OP_SERIAL_CONFIG);

#ifdef notdef
    if (ro == 1 && gpsc_state != GPSC_OFF) {
      gpsc_change_state(GPSC_ON, GPSW_GRANT);
      call GPSTimer.stop();
      switch (gps_speed) {
	default:
	case 0:
	  call Usart.setModeUart((msp430_uart_union_config_t *) &gps_57600_serial_config);
	  call Usart.enableIntr();
	  return;
	case 1:
	  call Usart.setModeUart((msp430_uart_union_config_t *) &gps_4800_serial_config);
	  call Usart.enableIntr();
	  return;
      }
    }
#endif

    if (gpsc_state == GPSC_OFF) {
      /*
       * We are off which means someone called stop after a request
       * was issued but the grant hadn't happened yet.  Since we got
       * the grant, that means there was an outstanding request.
       */
      gps_panic(16, 0);		/* do we ever see this? */
#ifndef GPS_LEAVE_UP
      call HW.gps_off();
#endif
      call GPSTimer.stop();
      mmP5out.ser_sel = SER_SEL_NONE;
      call SerialDemuxResource.release();
      return;
    }

    if (gpsc_state == GPSC_REQUESTED) {
      gpsc_change_state(GPSC_START_DELAY, GPSW_GRANT);
      call GPSTimer.startOneShotAt(t_gps_pwr_on, DT_GPS_PWR_UP_DELAY);
      call Usart.enableIntr();
      return;
    }
  }


  /*
   * SerialDemuxResource.granted
   *
   * event signalled when we have gained default control of the UART.  This only
   * occurs when we are first turning the GPS on.  When the GPS is started the
   * SerialDemuxResource is requested.  When granted it signifies that the GPS
   * now owns the UART by default.
   *
   * That doesn't mean the GPS owns the device.  A higher priority client
   * may actually own it.  So we need to check.
   */

  event void SerialDemuxResource.granted() {
    call MuxControl.set_mux(SERIAL_OWNER_GPS);
    call HW.gps_on();
    t_gps_pwr_on = call LocalTime.get();
    if (call SerialDefOwner.isOwner()) {
      gpsc_change_release_state(GPSC_RS_OWNED, GPSW_DEF_RESOURCE_GRANT);
      call Trace.trace(T_GPS_DO_GRANT, 2, 0);
      gps_granted();
    } else
      call Trace.trace(T_GPS_DO_DEFERRED, 2, 0);
  }

  /*
   * A user of the resource has finished and we are being told no one
   * else wants it.  So we are being given the resource because we are a
   * default owner.
   *
   * Note it is possible that by the time the gps_owner_task runs it is possible
   * that another user of the resource can have requested the resource which could
   * cause out state to be different that DEF_GRANTING.
   *
   * release_state must RELEASED.
   */

  async event void SerialDefOwner.granted() {
    if (gpsc_release_state != GPSC_RS_RELEASED)
      gps_panic(7, gpsc_state);
    gpsc_change_release_state(GPSC_RS_DEF_GRANTING, GPSW_DEF_GRANT);
    post gps_owner_task();
  }

  event void GPSTimer.fired() {
    error_t err;

    switch (gpsc_state) {
      default:
      case GPSC_FAIL:
      case GPSC_OFF:
      case GPSC_RECONFIG_4800_HUNTING:		// timed out.  no start char
      case GPSC_RECONFIG_4800_SENDING:		// timed out send.
      case GPSC_SENDING:			// send took too long
	gps_panic(8, gpsc_state);
	nop();
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
	if ((err = call UartStream.send(sirf_send_boot, sizeof(sirf_send_boot))))
	  call Panic.panic(PANIC_GPS, 9, err, gpsc_state, 0, 0);
	return;

	/*
	 * finish up in the task.  This allows other timers to fire and then
	 * we signal the boot completion from the config_task.
	 */
      case GPSC_FINI_WAIT:
	gpsc_change_state(GPSC_FINISH, GPSW_TIMER);
	post gps_config_task();
	return;

      case GPSC_RECONFIG_4800_PWR_DOWN:
	/*
	 * Doing a reconfig (see start_reconfig for sequence).
	 * gps was powered down.  Bring it back up and look for the
	 * start up sequence.  Should be NMEA@4800
	 *
	 * Earlier we called gps_off which will set the mux back to NONE.
	 * So when we come back we turn on and then connect the mux.  Note
	 * that we should still have ownership as far as the Arbiter is
	 * concerned.
	 */
	gpsc_change_state(GPSC_RECONFIG_4800_START_DELAY, GPSW_TIMER);
	call HW.gps_on();
	mmP5out.ser_sel = SER_SEL_GPS;
	t_gps_pwr_on = call LocalTime.get();
	call GPSTimer.startOneShotAt(t_gps_pwr_on, DT_GPS_PWR_UP_DELAY);
	call Usart.setModeUart((msp430_uart_union_config_t *) &gps_4800_serial_config);
	return;

      case GPSC_RECONFIG_4800_START_DELAY:
	gpsc_change_state(GPSC_RECONFIG_4800_HUNTING, GPSW_TIMER);
	call GPSTimer.startOneShot(DT_GPS_HUNT_LIMIT);
	call Usart.enableIntr();
	return;

      case GPSC_RECONFIG_4800_EOS_WAIT:
	gpsc_change_state(GPSC_RECONFIG_4800_SENDING, GPSW_TIMER);
	call GPSTimer.startOneShot(DT_GPS_SEND_TIME_OUT);
	if ((err = call UartStream.send(nmea_go_sirf_bin, sizeof(nmea_go_sirf_bin))))
	  call Panic.panic(PANIC_GPS, 10, err, gpsc_state, 0, 0);
	return;

      case GPSC_REQUESTED:			// request took too long
	gps_panic(11, gpsc_state);
	nop();
	return;

      case GPSC_START_DELAY:
	gpsc_change_state(GPSC_HUNT_1, GPSW_TIMER);
	post gps_config_task();

	/*
	 * kludge to try and get MID 4 sent back  Doesn't seem to work.
	 */
	call UartStream.send(sirf_send_start, sizeof(sirf_send_start));
	return;

      case GPSC_HUNT_1:
      case GPSC_HUNT_2:
	/*
	 * Oops.  Time out while hunting assume that the gps is misconfigured.
	 *
	 * . turn off interrupts
	 * . turn off gps power
	 * . force gpsc_state to 4800_PWR_DOWN
	 * . kick gps_config_task (gpsc_state tells it what to do).
	 */

	call Usart.disableIntr();		// going down, no interrupts while there

	/*
	 * DOES THIS RACE CONDITION STILL EXIST.
	 *
	 * There is a race condition where we've timed out, the timer will
	 * fire and eventually at task level GPSTimer.fired will be invoked.  If the rx
	 * interrupt (2nd start byte) occurs early enough it will cause gps_config_task
	 * to run prior to GPSTimer.fired.  (Either task ordering (if GPSTimer and config
	 * task "coincident" relative to the task level) or config_task gets posted and
	 * it runs prior to the gps timer going off)
	 *
	 * Once we get here, ints are off and we force to RECONFIG_4800_PWR_DOWN.  Once
	 * interrupts are turned off then the door is closed for the state change to
	 * EOS_WAIT.  If the interrupt got in prior to the interrupt disable
	 * then it will change state to EOS_WAIT and we will either be here (interrupt
	 * happened after the check of gpsc_state) or in the code below for EOS_WAIT (prior
	 * to the fetch of gpsc_state).  gps_config_task will still be posted.  So all
	 * of this should work with out a problem from the race condition.
	 *
	 * Reconfigure also dumps back into the HUNT_1 state.  The global variable
	 * gps_reconfig_trys determines how many times to try before dieing horribly.
	 */

	mmP5out.ser_sel = SER_SEL_NONE;
	call HW.gps_off();
	if (gpsc_reconfig_trys) {
	  gpsc_reconfig_trys--;
	  gpsc_change_state(GPSC_RECONFIG_4800_PWR_DOWN, GPSW_TIMER);
	  call GPSTimer.startOneShot(DT_GPS_PWR_BOUNCE);
	  call LogEvent.logEvent(DT_EVENT_GPS_RECONFIG, gpsc_reconfig_trys);
	  return;
	}
	gps_panic(12, gpsc_state);
	return;
    }
  }
  

  /*
   * NOTE on overruns and other rx errors.  The driver in
   * $TOSROOT/lib/tosthreads/chips/msp430/HplMsp430Usart1P.nc or
   * $TOSROOT/tos/chips/msp430/usart/HplMsp430Usart1P.nc
   * first reads U1RXBUF before signalling the interrupt.  This
   * clears out any errors that might be in U1RCTL.  We just
   * ignore for now.  In other words without modification errors
   * are not seen at upper layers.
   */
  async event void UartStream.receivedByte( uint8_t byte ) {
    /*
     * eaves drop on last GPS_EAVES_SIZE bytes from the gps
     */
    gbuf[g_idx++] = byte;
    if (g_idx >= GPS_EAVES_SIZE)
      g_idx = 0;

    call GPSMsg.byteAvail(byte);

    switch (gpsc_state) {
      case GPSC_ON:
	return;

      /*
       * In the following states we just eavesdrop.  And ignore.
       */
      case GPSC_RECONFIG_4800_EOS_WAIT:
      case GPSC_RECONFIG_4800_SENDING:
      case GPSC_EOS_WAIT:
      case GPSC_SENDING:
      case GPSC_FINI_WAIT:
      case GPSC_FINISH:
      case GPSC_REQUESTED:			/* small interrupt window between configure and grant, ignore */
      case GPSC_START_DELAY:
	return;					/* ignore (collected above) */

      case GPSC_HUNT_1:
     	if (byte == SIRF_BIN_START)
	  gpsc_change_state(GPSC_HUNT_2, GPSW_RXBYTE);
	return;

      case GPSC_HUNT_2:
	if (byte == SIRF_BIN_START_2) {
	  if (gpsc_operational) {
	    gpsc_change_state(GPSC_ON, GPSW_RXBYTE);
	    post gps_config_task();
	    return;
	  } else {
	    /*
	     * special sequence, wait for EOS window, then send to request info.
	     */
	    gpsc_change_state(GPSC_EOS_WAIT, GPSW_RXBYTE);
	    post gps_config_task();
	    return;
	  }
	} else if (byte == SIRF_BIN_START) {
	  /*
	   * looking for 2nd but got 1st, stay looking for second
	   */
	  return;
	} else {
	    /*
	     * Hunting for start sequence.  Saw the first one but the second didn't
	     * check out.  So look for the 1st char again.  Need to find the sequence
	     * before the timer goes off.
	     */
	  gpsc_change_state(GPSC_HUNT_1, GPSW_RXBYTE);
	  return;
	}
	return;

      case GPSC_RECONFIG_4800_HUNTING:
	if (byte == NMEA_START) {
	  /*
	   * we aren't very robust here.  we just assume if we see the
	   * $ then all is good.
	   */
	  gpsc_change_state(GPSC_RECONFIG_4800_EOS_WAIT, GPSW_RXBYTE);
	  post gps_config_task();
	  return;
	}
	return;

      default:
      case GPSC_OFF:
      case GPSC_FAIL:
      case GPSC_RECONFIG_4800_PWR_DOWN:
      case GPSC_RECONFIG_4800_START_DELAY:
	call Panic.panic(PANIC_GPS, 13, gpsc_state, byte, 0, 0);
	nop();			// less confusing.
	return;
    }
  }


  async event void UartStream.sendDone( uint8_t* buf, uint16_t len, error_t error ) {
    switch(gpsc_state) {
      case GPSC_RECONFIG_4800_SENDING:
	gpsc_change_state(GPSC_HUNT_1, GPSW_SEND_DONE);
	post gps_config_task();

	/*
	 * wait till all bytes have gone out.
	 */
	while (!call Usart.isTxEmpty()) ;
	call Usart.setModeUart((msp430_uart_union_config_t *) &GPS_OP_SERIAL_CONFIG);
	call Usart.enableIntr();
	return;

      case GPSC_SENDING:
	/*
	 * async context so need to kick to the config_task
	 */
	gpsc_change_state(GPSC_FINI_WAIT, GPSW_SEND_DONE);
	post gps_config_task();
	break;

      case GPSC_HUNT_1:			/* for the sirf_send_start send */
	break;

      case GPSC_BACK_TO_NMEA:
	gpsc_change_state(GPSC_FINI_WAIT, GPSW_SEND_DONE);
	post gps_config_task();
	while (!call Usart.isTxEmpty()) ;
	call Usart.setModeUart((msp430_uart_union_config_t *) &gps_4800_serial_config);
	call Usart.enableIntr();
	break;

      default:
	gps_panic(14, gpsc_state);
	break;
    }
    return;
  }


  /*
   * ignoreRelease
   *
   * Check current gps state and determine if we should ignore any requested release.
   *
   * Keep others out if:
   *     In the bootstrap (GPSC_OFF <= state < GPSC_REQUESTED)
   *     In initial turn on: (state is START_DELAY, HUNT1, HUNT2).
   *     RELEASING (do to timing and things happening coincident)
   *
   * Release if:
   *	 REQUESTED
   *	 ON
   *
   * Illegal states checked and panic if appropriate.
   */

  bool ignoreRelease() {
    if (gpsc_state == GPSC_REQUESTED || gpsc_state == GPSC_ON)
      return FALSE;

    /* Boot up states, ignore */
    if (gpsc_state >= GPSC_OFF && gpsc_state < GPSC_REQUESTED)
      return TRUE;

    /* START_DELAY, HUNT_1, HUNT_2 -> TRUE (ignoreRelease) */
    if (gpsc_state > GPSC_REQUESTED && gpsc_state < GPSC_ON)
      return TRUE;
    gps_panic(17, gpsc_state);
    return TRUE;
  }


  /*
   * GPS Message layer is signalling that we have arrived at a message
   * boundary.  Check to see if the h/w has been requested.
   */
  async event void GPSMsg.msgBoundary() {
    atomic {
      if (gpsc_release_state != GPSC_RS_OWNED) {
	gps_panic(19, gpsc_release_state);
      }
      if (ignoreRelease())
	return;
      if (othersWaiting == FALSE)
	return;

      /*
       * don't let any more bytes come in, we are releasing.
       */
      call Usart.disableIntr();
      gpsc_change_release_state(GPSC_RS_RELEASING, GPSW_MSG_BOUNDARY);
      call Trace.trace(T_GPS_RELEASING, 1, 0);
      post gps_owner_task();
    }
  }


  /*
   * A Client is requesting the resource from the Default Owner (us, gps)
   *
   * OFF -> always release.
   */
  async event void SerialDefOwner.requested() {
    atomic {
      /*
       * If we are off, then we don't own the resource but the
       * mux hasn't been switched yet (race condition).  Simply
       * release so the higher priority device gets ownership.
       */
      call Trace.trace(T_GPS_DO_REQUESTED, gpsc_state, gpsc_release_state);
      if (gpsc_state == GPSC_OFF) {
	call SerialDefOwner.release();
	return;
      }

      /*
       * remember that the event occurred.
       */
      othersWaiting = TRUE;

      /*
       * REQUESTED is handled special in that we will eventually make some kind
       * of progress.  This gets us to the point where the gps will start seeing
       * messages.
       */
      if (gpsc_state == GPSC_REQUESTED) {
	if (--gpsc_request_defers == 0) {
	  gpsc_request_defers = MAX_GPS_DEFERS;
	  return;
	} else {
	  call Trace.trace(T_GPS_DO_DEFERRED, 3, gpsc_request_defers);
	}
      } else {
	if (ignoreRelease())
	  return;
      }

      /*
       * We've already looked at gpsc_state and we aren't ignoring the release request.
       * check current release_state.  If OWNED we also check for MsgBoundary.  Otherwise
       * just assume that the transient requester has priority and give it to it.
       */
      switch (gpsc_release_state) {
	case GPSC_RS_OWNED:
	  if (call GPSMsg.atMsgBoundary() == FALSE)
	    return;
	  /*
	   * We are owned and at a MsgBoundary so fall through and release
	   */
	case GPSC_RS_RELEASED:
	case GPSC_RS_DEF_GRANTING:
	case GPSC_RS_RELEASING:
	  call Usart.disableIntr();
	  gpsc_change_release_state(GPSC_RS_RELEASING, GPSW_DEF_REQUESTED);
	  call Trace.trace(T_GPS_RELEASING, 2, 0);
	  post gps_owner_task();
	  return;

	default:
	  gps_panic(20, gpsc_release_state);
	  return;
      }
    }
  }

  async event void UartStream.receiveDone( uint8_t* buf, uint16_t len, error_t error ) { }
  async event void SerialDefOwner.immediateRequested() { } 
}
