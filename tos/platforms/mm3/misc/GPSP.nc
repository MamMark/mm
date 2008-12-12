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
   * 57600-SirfBin.  We 
   *
   * Boot up windows are defined from when the gps is turned on (t_gps_pwr_on)
   *
   * [START_DELAY is used to have the gps powered up but the cpu is not taking any interrupts from
   * it.  This allows the CPU to be sleeping while the gps is doing its power up thing.  It takes about
   * 300ms before it starts sending bytes.  This allows things to settle down before we start looking
   * for the first byte.]
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
   * power up and any communication it needs).  This creates problems
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

  GPSC_REQUESTED,			// waiting for usart
  GPSC_START_DELAY,			// power on
  GPSC_HUNT_1,				// Can we see them?
  GPSC_HUNT_2,
  GPSC_ON,
  GPSC_RELEASING,			// release and re-request, prev_state valid
  GPSC_BACK_TO_NMEA,

} gpsc_state_t;


typedef enum {
  GPSW_NONE =			0,
  GPSW_GRANT =			1,
  GPSW_TIMER =			2,
  GPSW_RXBYTE =			3,
  GPSW_CONFIG_TASK =		4,
  GPSW_SEND_DONE =		5,
  GPSW_MSG_BOUNDARY =		6,
  GPSW_RESOURCE_REQUESTED =	7,
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


norace gpsc_state_t gpsc_state;	// low level collector state


module GPSP {
  provides {
    interface Init;
    interface SplitControl as GPSControl;
    interface Msp430UartConfigure;
    interface Boot as GPSBoot;
  }
  uses {
    interface Boot;
    interface Resource as UARTResource;
    interface ResourceRequested as UARTResourceRequested;
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
  }
}


implementation {

  norace gpsc_state_t gpsc_prev_state;  // releasing, previous state
  norace uint32_t     t_gps_pwr_on;
  norace uint8_t      gpsc_reconfig_trys;
  norace bool	      gpsc_operational;	// if 0 then booting, do special stuff

  void gpsc_change_state(gpsc_state_t next_state, gps_where_t where) {

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

    gpsc_state = next_state;

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
   * shut down gps,  this is the guts of gpscontrol.stop without
   * the stopDone call back.
   */
  void control_stop() {
    call Usart.disableIntr();
#ifndef GPS_LEAVE_UP
    call HW.gps_off();
#endif
    call GPSTimer.stop();
    call LogEvent.logEvent(DT_EVENT_GPS_OFF, 0);
    gpsc_change_state(GPSC_OFF, GPSW_NONE);
    if (call UARTResource.isOwner()) {
      if (call UARTResource.release() != SUCCESS)
	gps_panic(1, 0);
      mmP5out.ser_sel = SER_SEL_NONE;
    }
    call GPSMsgControl.stop();
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
	gps_panic(2, cur_gps_state);
	return;

      case GPSC_OFF:
	call GPSTimer.stop();
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
	signal GPSBoot.booted();
	return;

      case GPSC_HUNT_1:
      case GPSC_HUNT_2:
	call GPSTimer.startOneShot(DT_GPS_HUNT_LIMIT);
	return;

      case GPSC_ON:
	call GPSTimer.stop();
	signal GPSControl.startDone(SUCCESS);
	return;

      case GPSC_RELEASING:
	/*
	 * note: anytime we change state to GPSC_RELEASING, uart interrupts will be
	 * turned off.  Because we are releasing to some other user and will be deconfiguring.
	 * We don't want anymore events occuring that might try to change what we are doing.
	 */
	call LogEvent.logEvent(DT_EVENT_GPS_RELEASE, 0);
	call UARTResource.release();
	call GPSMsg.reset();
	call GPSTimer.startOneShot(DT_GPS_MAX_REQUEST_TO);
	call UARTResource.request();
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
    t_gps_pwr_on = 0;
    gpsc_reconfig_trys = MAX_GPS_RECONFIG_TRYS;
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
    if (call UARTResource.isOwner())
      call UARTResource.release();
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
   * During the granting process the GPS will be configured along with
   * the USART used to talk to it.  During this process interrupts
   * will be enabled and we should be prepared to handle them even
   * though we haven't gotten the grant back yet (the arbiter
   * configures then grants).  We explicitly handle turning interrupts
   * for the UART/USART/GPS to control when we want to see them or not.
   */

  command error_t GPSControl.start() {
    error_t err;

    if (gpsc_state != GPSC_OFF)
      return FAIL;
    call LogEvent.logEvent(DT_EVENT_GPS_START,0);
    gpsc_change_state(GPSC_REQUESTED, GPSW_NONE);
    call GPSMsgControl.start();
    call GPSTimer.startOneShot(DT_GPS_MAX_REQUEST_TO);
    call Trace.trace(T_GPS, 0x20, 0);
    err = call UARTResource.request();
    call Trace.trace(T_GPS, 0x21, 0);
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
    signal GPSControl.stopDone(SUCCESS);
    return SUCCESS;
  }


  /*
   * UARTResource.granted
   *
   * Called when the arbiter gives us control of the UART (also the underlying USART)
   * It will have already called the configurator which turns the gps on, sets the
   * serial mux to gps, and sets the uart baud to the default.
   */

  event void UARTResource.granted() {
    call Usart.disableIntr();
    call LogEvent.logEvent(DT_EVENT_GPS_GRANT, gpsc_state);

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

    switch (gpsc_state) {
      default:
	call Panic.panic(PANIC_GPS, 3, gpsc_state, 0, 0, 0);
	nop();
	return;

      case GPSC_OFF:
	/*
	 * We are off which means someone called stop after a request
	 * was issued but the grant hadn't happened yet.  Since we got
	 * the grant, that means there was an outstanding request.
	 * Prior to the grant being issued the configure will have
	 * turned the gps back on so we want to turn it off again.
	 */
#ifndef GPS_LEAVE_UP
	call HW.gps_off();
#endif
	call GPSTimer.stop();
	mmP5out.ser_sel = SER_SEL_NONE;
	call UARTResource.release();
	return;

      case GPSC_REQUESTED:
	gpsc_change_state(GPSC_START_DELAY, GPSW_GRANT);
	call GPSTimer.startOneShotAt(t_gps_pwr_on, DT_GPS_PWR_UP_DELAY);
	call Usart.enableIntr();
	break;

      case GPSC_RELEASING:
	gpsc_change_state(gpsc_prev_state, GPSW_GRANT);
	switch(gpsc_prev_state) {
	  default:
	    call Panic.panic(PANIC_GPS, 4, gpsc_state, 0, 0, 0);
	    break;
	  case GPSC_START_DELAY:
	    call GPSTimer.startOneShotAt(t_gps_pwr_on, DT_GPS_PWR_UP_DELAY);
	    break;
	  case GPSC_SENDING:
	    call GPSTimer.startOneShot(DT_GPS_SEND_TIME_OUT);
	    break;
	  case GPSC_HUNT_1:
	    call GPSTimer.startOneShot(DT_GPS_HUNT_LIMIT);
	    break;
	  case GPSC_ON:
	    call GPSTimer.stop();
	    break;
	}
	call Usart.enableIntr();
	break;
    }
    return;
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
      case GPSC_RELEASING:			// request hung?
	call Panic.panic(PANIC_GPS, 5, gpsc_state, 0, 0, 0);
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
	  call Panic.panic(PANIC_GPS, 8, err, gpsc_state, 0, 0);
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
	  call Panic.panic(PANIC_GPS, 9, err, gpsc_state, 0, 0);
	return;

      case GPSC_REQUESTED:			// request took too long
	call Panic.panic(PANIC_GPS, 6, gpsc_state, 0, 0, 0);
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
	gps_panic(7, gpsc_state);
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
      case GPSC_OFF:
	/*
	 * We can be in the OFF state but still got an interrupt.  There is a small window
	 * if we have requested and not been granted and a STOP is issued.  The STOP will
	 * set state to OFF and turn things off.  But the request is still outstanding and
	 * when granted the UART configurator will turn the GPS on with interrupts enabled.
	 * Once the grant is issued, the gps is shut down.  But during this time it is
	 * possible to take an interrupt.  Just ignore it.
	 */
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
      case GPSC_REQUESTED:		/* small interrupt window between configure and grant, ignore */
      case GPSC_START_DELAY:
      case GPSC_RELEASING:
	return;					// ignore (collected above)

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
      case GPSC_FAIL:
      case GPSC_RECONFIG_4800_PWR_DOWN:
      case GPSC_RECONFIG_4800_START_DELAY:
	call Panic.panic(PANIC_GPS, 11, gpsc_state, byte, 0, 0);
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
	call Panic.panic(PANIC_GPS, 12, gpsc_state, 0, 0, 0);
	break;
    }
    return;
  }


  async event void GPSMsg.msgBoundary() {
    atomic {
      /*
       * ignore if reconfiguring.  Or in the initial non-operational boot
       * up state.
       */
      if (gpsc_state > GPSC_OFF && gpsc_state < GPSC_REQUESTED)
	return;
      if (gpsc_state == GPSC_RELEASING)
	return;
      if (call UARTResource.othersWaiting()) {
	/*
	 * don't let any more bytes come in, we are releasing.
	 */
	call Usart.disableIntr();
	gpsc_prev_state = gpsc_state;
	gpsc_change_state(GPSC_RELEASING, GPSW_MSG_BOUNDARY);
	post gps_config_task();
	return;
      }
      /*
       * no release needed.
       */
    }
  }


  async event void UARTResourceRequested.requested() {
    atomic {
      /*
       * ignore if we are booting
       */
      if (gpsc_state > GPSC_OFF && gpsc_state < GPSC_REQUESTED)
	return;
      if (gpsc_state == GPSC_RELEASING)
	return;
      if (call GPSMsg.atMsgBoundary()) {
	call Usart.disableIntr();
	gpsc_prev_state = gpsc_state;
	gpsc_change_state(GPSC_RELEASING, GPSW_RESOURCE_REQUESTED);
	post gps_config_task();
	return;
      }
    }
  }

  
  async event void UARTResourceRequested.immediateRequested() {
  }


  async event void UartStream.receiveDone( uint8_t* buf, uint16_t len, error_t error ) {
  }


  /*
   * Called from within the Usart configurator.
   *
   * We configure to the DEFAULT OP serial on grant.  If the baud needs to be
   * changed it is done using an explicit call to the configurator.
   */
  async command msp430_uart_union_config_t* Msp430UartConfigure.getConfig() {
    call HW.gps_on();
    mmP5out.ser_sel = SER_SEL_GPS;
    t_gps_pwr_on = call LocalTime.get();
    return (msp430_uart_union_config_t*) &GPS_OP_SERIAL_CONFIG;
  }
}
