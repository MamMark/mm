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


#ifdef TEST_GPS_FUTZ

noinit uint8_t gps_speed;		// will default to 0, 57600 (1 is 4800, 2 is 115200 (if compiled in))
noinit uint8_t ro;
noinit uint16_t recv_count;
noinit uint8_t gc;

/*
 * gc (gps_cmd)
 *      0: bootup commands (send sw ver, clock status)
 *	1: mid 41 off, no poll   (combined 1st half, 16)
 *	2: mid  2 off, no poll   (combined 2nd half, [16], 16)
 *	3: mid 41 off, with poll (sirf_poll_29)
 *	4: combined.  mid 41 off no poll, mid 2 off no poll
 *
 *	9: switch to nmea (assumes currently sirf_bin)
 */

#define MAX_GC 9

#endif		// TEST_GPS_FUTZ

#define GPS_EAVES_SIZE 2048

uint8_t gbuf[GPS_EAVES_SIZE];
norace uint16_t g_idx;


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
   * Boot up states.  When first booted these are the states we move through.
   *
   * Boot up windows are defined from when the gps is turned on (t_gps_pwr_on)
   *
   * BOOT_REQUESTED		uart_grant	BOOT_START_DELAY
   *                                          (uart interrupts disabled)
   *						(timer <- t_gps_pwr_on + boot_up_delay)
   *
   * [START_DELAY is used to have the gps powered up but the cpu is not taking any interrupts from
   * it.  This allows the CPU to be sleeping while the gps is doing its power up thing.  It takes about
   * 300ms before it starts sending bytes.  This allows things to settle down before we start looking
   * for the first byte.]
   *
   * BOOT_START_DELAY		timer fired	BOOT_HUNTING
   *                                          	(timer <- t_gps_pwr_on + hunt_window)
   *					      	(uart interrupts enabled)
   *				rx byte         (panic, interrupts should be off)
   *
   * [When in the BOOT_HUNTING state, we are looking for the start sequence.  If we see back to
   * back start chars (SIRF_BIN_START, SIRF_BIN_START_2) then we complete the HUNTING state
   * and assume that we are communicating.]
   *
   * BOOT_HUNT_1		timer fired	time out, reconfig sequence
   * 				rx start chr	BOOT_HUNT_2
   * BOOT_HUNT_2		timer fired	time out, reconfig sequence
   * 				rx 2nd start	BOOT_EOS_WAIT.
   *
   * normally we figure if we saw the start sequence then that is good enough.  So we would turn
   * the sucker off and signal booted.  Extra states are provided for messing around.
   *
   * [BOOT_EOS_WAIT ** extra ***: wait for the start up window to close.  When the gps first powers up
   * it takes 300ms before starting to send chars (that is when we get out of HUNT), this is the
   * gps start up stream being transmitted.  If we try to send commands to the gps during this time
   * it will be ignored.  So we define a window that must close before we send anything.  BOOT_EOS_WAIT
   * denotes this state.  At the end of BOOT_EOS_WAIT when futzing we can send a command to the gps
   * to see what happens (sc tells what command to send).  BOOT_FINI_WAIT then waits some amount of
   * time (to collect characters) before shutting down and signalling booted.
   *
   * Approach...  look for start sequence and call it a day if seen.
   * If we see the start sequence, then just turn the thing off and signal
   * booted.   BOOT_EOS_WAIT is for screwing around.  possibly sending
   * a command.  At the end of what ever we are messing around with then
   * signal booted.
   *
   * turn on, wait 
   *
   *    BOOT_REQUESTED			wait for grant
   *	BOOT_START_DELAY		pwr on, ints off
   *	BOOT_HUNT_1			ints on, looking for first char.
   *	BOOT_HUNT_2			looking for second.
   *	BOOT_EOS_WAIT			first char seen, wait till okay to send.  (used for send command)
   *    BOOT_SENDING			sending bootup commands.
   *    BOOT_FINI_WAIT			wait after last command to give enough time for it to take.
   *    BOOT_FINISH			send boot signal from config task.
   */

  GPSC_BOOT_REQUESTED,
  GPSC_BOOT_START_DELAY,		// turn on delay, gps power on, ints off
  GPSC_BOOT_HUNT_1,			// ints on,  find start up sequence.  (window: DT_GPS_HUNT_WINDOW)
  GPSC_BOOT_HUNT_2,			// ints on,  look for second start
  GPSC_BOOT_EOS_WAIT,			// waiting for end of start window so we can send.
  GPSC_BOOT_SENDING,			// sending boot commands
  GPSC_BOOT_FINI_WAIT,			// waiting after last boot command.
  GPSC_BOOT_FINISH,			// all done, signal booted from config task.

  GPSC_RECONFIG_4800_PWR_DOWN,		// power down
  GPSC_RECONFIG_4800_START_DELAY,	// gps power on, ints off
  GPSC_RECONFIG_4800_HUNTING,		// looking for '$', nmea start
  GPSC_RECONFIG_4800_EOS_WAIT,		// waiting for end of start
  GPSC_RECONFIG_4800_SENDING,		// waiting for send of go_sirf_bin to complete

  /*
   * Normal sequencing.   GPS is assumed to be configured for SirfBin@op speed
   */
  GPSC_REQUESTED,			// waiting for usart
  GPSC_START_DELAY,			// power on, cpu sleeping
  GPSC_SENDING,				// sending commands we want to force
  GPSC_HUNT_1,				// Can we see them?
  GPSC_HUNT_2,				// 
  GPSC_ON,
  GPSC_BACK_TO_NMEA,
} gpsc_state_t;


typedef enum {
  GPSW_NONE = 0,
  GPSW_GRANT = 1,
  GPSW_TIMER = 2,
  GPSW_RXBYTE = 3,
  GPSW_CONFIG_TASK = 4,
  GPSW_SEND_DONE = 5,
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


module GPSP {
  provides {
    interface Init;
    interface StdControl as GPSControl;
    interface Msp430UartConfigure;
    interface Boot as GPSBoot;
  }
  uses {
    interface Boot;
    interface Resource as UARTResource;
    interface Timer<TMilli> as GPSTimer;
    interface LocalTime<TMilli>;
    interface HplMM3Adc as HW;
    interface UartStream;
    interface Panic;
    interface HplMsp430Usart as Usart;
    interface GPSByte;
    interface StdControl as GPSMsgControl;
  }
}


implementation {

  norace gpsc_state_t gpsc_state;	/* low level collector state */
  norace uint32_t     t_gps_pwr_on;
  norace uint8_t      gpsc_boot_trys;


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

//#ifdef notdef
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
//#endif

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

	/*
	 * we could use a shorter time here but 2 seconds isn't that long
	 * And this will only timeout if the gps is set to 4800 baud.  That
	 * 
	 */
      case GPSC_BOOT_HUNT_1:
	call GPSTimer.startOneShot(DT_GPS_HUNT_LIMIT);
	return;

      case GPSC_BOOT_EOS_WAIT:
      case GPSC_RECONFIG_4800_EOS_WAIT:
	call GPSTimer.startOneShotAt(t_gps_pwr_on, DT_GPS_EOS_WAIT);
	return;

      case GPSC_BOOT_FINI_WAIT:
	call GPSTimer.startOneShot(DT_GPS_FINI_WAIT);
	return;

      case GPSC_BOOT_FINISH:
	call GPSControl.stop();
	nop();				// BRK_FINISH
	signal GPSBoot.booted();
	return;

      case GPSC_HUNT_1:
	call GPSTimer.startOneShot(DT_GPS_HUNT_LIMIT);
	return;

      case GPSC_ON:
	call UARTResource.release();
	call GPSByte.reset();
	call UARTResource.request();
	call GPSTimer.startOneShot(DT_LISTEN_TIME);
	return;
    }
  }

  command error_t Init.init() {
    if (ro > 1)
      ro = 0;
    if (gps_speed > 1)
      gps_speed = 0;
    if (gc > MAX_GC)
      gc = 0;

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
    gpsc_boot_trys = MAX_GPS_BOOT_TRYS;
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
     */
    call HW.gps_off();
    if (call UARTResource.isOwner())
      call UARTResource.release();
    gpsc_change_state(GPSC_BOOT_REQUESTED, GPSW_NONE);
    call GPSMsgControl.start();

    /*
     * The request when granted will turn on the GPS.
     * Start a timer to catch the grant never being issued.
     */
    call GPSTimer.startOneShot(DT_GPS_MAX_REQUEST_TO);
    call UARTResource.request();
  }

  /*
   * Start GPS.
   *
   * This is what is normally used to fire the GPS up for readings.
   * Assumes the gps has its comm settings properly setup.  SirfBin-57600
   *
   * Some thoughts...
   *
   * 1) Turn the gps on.  start timer for pwr up interrupts off window.  The device
   *    won't start talking for about 300ms or so (note tinyos timers are in mis
   *    units).   We also want to give the gps enough time to recapture.
   *
   * 2) Throw
   *    
   * 2) can we immediately throw commands requesting the navigation data we want?
   * 3) can we send commands back to back?
   * 4) is it reliable?
   * 5) would it be better to sequence?
   * 6) do we want nav data as meters or geodetic?  (mid 2 or mid 41)
   * 7) what is the byte order?  sirf is big endian.  the msp430 is little endian.
   * 8) On boot we may want to actually run a simplified state machine for the
   *    NMEA.  It would be more robust.  See if we can get away with what we've
   *    got.  (That is looking for just the first char seen as the indicator of
   *    goodness).
   *
   * 9) Wait for a while and then send a command.  What does the GPS do?  Then
   *    back it up and see when is the earliest we can send it.
   *
   * During the granting process the GPS will be configured along with
   * the USART used to talk to it.  During this process interrupts
   * will be enabled and we should be prepared to handle them even
   * though we haven't gotten the grant back yet (the arbiter
   * configures then grants.
   */

  command error_t GPSControl.start() {
    if (gpsc_state != GPSC_OFF)
      return FAIL;
    gpsc_change_state(GPSC_REQUESTED, GPSW_NONE);
    call GPSMsgControl.start();
    return call UARTResource.request();
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
    call Usart.disableIntr();
    call HW.gps_off();
    call GPSTimer.stop();
    gpsc_change_state(GPSC_OFF, GPSW_NONE);
    if (call UARTResource.isOwner()) {
      call UARTResource.release();
      mmP5out.ser_sel = SER_SEL_NONE;
    }
    call GPSMsgControl.stop();
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

    switch (gpsc_state) {
      default:
	call Panic.panic(PANIC_GPS, 1, gpsc_state, 0, 0, 0);
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
	call HW.gps_off();
	call GPSTimer.stop();
	mmP5out.ser_sel = SER_SEL_NONE;
	call UARTResource.release();
	return;

      case GPSC_BOOT_REQUESTED:
	gpsc_change_state(GPSC_BOOT_START_DELAY, GPSW_GRANT);
	call GPSTimer.startOneShotAt(t_gps_pwr_on, DT_GPS_BOOT_UP_DELAY);
	break;

      case GPSC_REQUESTED:
	gpsc_change_state(GPSC_START_DELAY, GPSW_GRANT);
	call GPSTimer.startOneShotAt(t_gps_pwr_on, DT_GPS_PWR_UP_DELAY);
	break;

      case GPSC_ON:
	call GPSTimer.startOneShot(DT_LISTEN_TIME);
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
      case GPSC_BOOT_REQUESTED:			// very strange.  (timed out)
      case GPSC_BOOT_SENDING:			// timed out.
      case GPSC_RECONFIG_4800_HUNTING:		// timed out.  no start char
      case GPSC_RECONFIG_4800_SENDING:	// timed out send.
      case GPSC_REQUESTED:
      case GPSC_SENDING:
	call Panic.panic(PANIC_GPS, 2, gpsc_state, 0, 0, 0);
	nop();
	return;

      case GPSC_BOOT_START_DELAY:
	gpsc_change_state(GPSC_BOOT_HUNT_1, GPSW_TIMER);
	call GPSTimer.startOneShot(DT_GPS_HUNT_LIMIT);
	call Usart.enableIntr();
	return;

      case GPSC_BOOT_HUNT_1:
      case GPSC_BOOT_HUNT_2:
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
	 * There is a race condition where we've timed out, the timer will
	 * fire and eventually at task level GPSTimer.fired will be invoked.  If the rx
	 * interrupt (2nd start byte) occurs early enough it will cause gps_config_task
	 * to run prior to GPSTimer.fired.  (Either task ordering (if GPSTimer and config
	 * task "coincident" relative to the task level) or config_task gets posted and
	 * it runs prior to the gps timer going off)
	 *
	 * Once we get here, ints are off and we force to RECONFIG_4800_PWR_DOWN.  Once
	 * interrupts are turned off then the door is closed for the state change to
	 * BOOT_EOS_WAIT.  If the interrupt got in prior to the interrupt disable
	 * then it will change state to BOOT_EOS_WAIT and we will either be here (interrupt
	 * happened after the check of gpsc_state) or in the code below for BOOT_EOS_WAIT (prior
	 * to the fetch of gpsc_state).  gps_config_task will still be posted.  So all
	 * of this should work with out a problem from the race condition.
	 *
	 * Reconfigure also dumps back into the BOOT_HUNT_1 state.  The global variable
	 * gps_boot_trys determines how many times to try before dieing horribly.
	 */

	call HW.gps_off();
	if (gpsc_boot_trys) {
	  gpsc_boot_trys--;
	  gpsc_change_state(GPSC_RECONFIG_4800_PWR_DOWN, GPSW_TIMER);
	  call GPSTimer.startOneShot(DT_GPS_PWR_BOUNCE);
	  return;
	}
	gps_panic(2, gpsc_state);
	return;

      case GPSC_BOOT_EOS_WAIT:
	/*
	 * Being in this state says we saw the start char sequence and enough
	 * time has gone by to allow us to send commands and not have them ignored.
	 * Start sending boot commands from the list.  sendDone handles sending
	 * the next.  The receiver code handles collecting any responses.  When the
	 * last command is sent go into FINI_WAIT to finish collecting responses.
	 */
	switch(gc) {
	  default:
	  case 0:
	    gpsc_change_state(GPSC_BOOT_SENDING, GPSW_TIMER);
	    call GPSTimer.startOneShot(DT_GPS_SEND_TIME_OUT);
	    if ((err = call UartStream.send(sirf_send_boot, sizeof(sirf_send_boot))))
	      call Panic.panic(PANIC_GPS, 90, err, gpsc_state, gc, 0);
	    return;
	  case 1:		// 1st half, combined, len 16
	    if ((err = call UartStream.send(sirf_combined, 16)))
	      call Panic.panic(PANIC_GPS, 90, err, gpsc_state, gc, 0);
	    return;
	  case 2:		// 2nd half, &combined[16], len 16
	    if ((err = call UartStream.send(&sirf_combined[16], 16)))
	      call Panic.panic(PANIC_GPS, 90, err, gpsc_state, gc, 0);
	    return;
	  case 3:
	    if ((err = call UartStream.send(sirf_poll_41, sizeof(sirf_poll_41))))
	      call Panic.panic(PANIC_GPS, 90, err, gpsc_state, gc, 0);
	    return;
	  case 4:
	    if ((err = call UartStream.send(sirf_combined, sizeof(sirf_combined))))
	      call Panic.panic(PANIC_GPS, 90, err, gpsc_state, gc, 0);
	    return;
	  case 9:
	    if ((err = call UartStream.send(sirf_go_nmea, sizeof(sirf_go_nmea))))
	      call Panic.panic(PANIC_GPS, 90, err, gpsc_state, gc, 0);
	    gpsc_change_state(GPSC_BACK_TO_NMEA, GPSW_TIMER);
	    return;
	}
	return;

	/*
	 * finish up in the task.  This allows other timers to fire and then
	 * we signal the boot completion from the config_task.
	 */
      case GPSC_BOOT_FINI_WAIT:
	gpsc_change_state(GPSC_BOOT_FINISH, GPSW_TIMER);
	post gps_config_task();
	return;

      case GPSC_RECONFIG_4800_PWR_DOWN:
	/*
	 * Doing a reconfig (see start_reconfig for sequence).
	 * gps was powered down.  Bring it back up and look for the
	 * start up sequence.  Should be NMEA@4800
	 */
	gpsc_change_state(GPSC_RECONFIG_4800_START_DELAY, GPSW_TIMER);
	call HW.gps_on();
	t_gps_pwr_on = call LocalTime.get();
	call GPSTimer.startOneShotAt(t_gps_pwr_on, DT_GPS_BOOT_UP_DELAY);
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
	  call Panic.panic(PANIC_GPS, 91, err, gpsc_state, 0, 0);
	return;

      case GPSC_START_DELAY:
	gpsc_change_state(GPSC_SENDING, GPSW_TIMER);
	call GPSTimer.startOneShot(DT_GPS_SEND_TIME_OUT);
	call Usart.enableIntr();
	if ((err = call UartStream.send(sirf_poll_41, sizeof(sirf_poll_41))))
	  call Panic.panic(PANIC_GPS, 91, err, gpsc_state, 0, 0);
	return;

      case GPSC_ON:				// forgot to kill the timer
	call UARTResource.release();
	call GPSByte.reset();
	call UARTResource.request();
	return;
    }
  }
  

  /*
   * NOTE on overruns and other rx errors.  The driver in
   * $TOSROOT/lib/tosthreads/chips/msp430/HplMsp430Usart1P.nc or
   * $TOSROOT/tos/chips/msp430/usart/HplMsp430Usart1P.nc
   *
   * first reads U1RXBUF before signalling the interrupt.  This
   * clears out any errors that might be in U1RCTL.  We just
   * ignore for now.
   */
  async event void UartStream.receivedByte( uint8_t byte ) {
    /*
     * eaves drop on last GPS_EAVES_SIZE bytes from the gps
     */
    gbuf[g_idx++] = byte;
    if (g_idx >= GPS_EAVES_SIZE)
      g_idx = 0;

    call GPSByte.byte_avail(byte);

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
      case GPSC_BOOT_EOS_WAIT:
      case GPSC_BOOT_SENDING:
      case GPSC_BOOT_FINI_WAIT:
      case GPSC_BOOT_FINISH:
      case GPSC_RECONFIG_4800_EOS_WAIT:
      case GPSC_RECONFIG_4800_SENDING:
      case GPSC_SENDING:
	return;					// ignore (collect above)

      case GPSC_BOOT_HUNT_1:
     	if (byte == SIRF_BIN_START)
	  gpsc_change_state(GPSC_BOOT_HUNT_2, GPSW_RXBYTE);
	return;

      case GPSC_BOOT_HUNT_2:
	if (byte == SIRF_BIN_START_2) {
	  gpsc_change_state(GPSC_BOOT_EOS_WAIT, GPSW_RXBYTE);
	  post gps_config_task();
	  return;
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
	  gpsc_change_state(GPSC_BOOT_HUNT_1, GPSW_RXBYTE);
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

      case GPSC_HUNT_1:
     	if (byte == SIRF_BIN_START)
	  gpsc_change_state(GPSC_HUNT_2, GPSW_RXBYTE);
	return;

      case GPSC_HUNT_2:
	if (byte == SIRF_BIN_START_2) {
	  gpsc_change_state(GPSC_ON, GPSW_RXBYTE);
	  post gps_config_task();
	  return;
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

      default:
      case GPSC_FAIL:
      case GPSC_BOOT_START_DELAY:		// interrupts shouldn't be on.  why are we here?
      case GPSC_RECONFIG_4800_PWR_DOWN:
      case GPSC_RECONFIG_4800_START_DELAY:
      case GPSC_START_DELAY:
	call Panic.panic(PANIC_GPS, 99, gpsc_state, byte, 0, 0);
	nop();			// less confusing.
	return;
    }
  }


  async event void UartStream.sendDone( uint8_t* buf, uint16_t len, error_t error ) {
    switch(gpsc_state) {
      case GPSC_RECONFIG_4800_SENDING:
	gpsc_change_state(GPSC_BOOT_HUNT_1, GPSW_SEND_DONE);
	post gps_config_task();

	/*
	 * wait till all bytes have gone out.
	 */
	while (!call Usart.isTxEmpty()) ;
	call Usart.setModeUart((msp430_uart_union_config_t *) &GPS_OP_SERIAL_CONFIG);
	call Usart.enableIntr();
	return;

      case GPSC_BOOT_EOS_WAIT:
      case GPSC_BOOT_SENDING:
	/*
	 * async context so need to kick to the config_task
	 */
	gpsc_change_state(GPSC_BOOT_FINI_WAIT, GPSW_SEND_DONE);
	post gps_config_task();
	break;

      case GPSC_SENDING:
	gpsc_change_state(GPSC_HUNT_1, GPSW_SEND_DONE);
	post gps_config_task();
	break;
	
      case GPSC_BACK_TO_NMEA:
	gpsc_change_state(GPSC_BOOT_FINI_WAIT, GPSW_SEND_DONE);
	post gps_config_task();
	while (!call Usart.isTxEmpty()) ;
	call Usart.setModeUart((msp430_uart_union_config_t *) &gps_4800_serial_config);
	call Usart.enableIntr();
	break;

      default:
	call Panic.panic(PANIC_GPS, 98, gpsc_state, gc, 0, 0);
	break;
    }
    return;
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
    mmP5out.ser_sel = SER_SEL_GPS;
    call HW.gps_on();
    t_gps_pwr_on = call LocalTime.get();
    return (msp430_uart_union_config_t*) &GPS_OP_SERIAL_CONFIG;
  }
}
