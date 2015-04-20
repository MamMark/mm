/*
 * Copyright (c) 2008-2010, 2012, 2014 Eric B. Decker
 * All rights reserved.
 *
 * @author Eric B. Decker (cire831@gmail.com)
 * @date 12 May 2012
 *
 * org4472 driver, dedicated 5438 usci spi port
 * based on dedicated 2618 usci uart port sirf3 driver.
 */

#include "panic.h"
#include "gps.h"
#include "sirf.h"

#define GPS_EAVES_SIZE 2048

uint8_t gbuf[GPS_EAVES_SIZE];
uint16_t g_idx;

#include "platform_spi_org4472.h"

typedef enum {
  GPSC_FAIL = 1,
  GPSC_OFF,

  /*
   * The ORG4472 GPS module is interfaced using SPI at 4MHz.  It can communicate
   * using NMEA or OSP (One Socket Protocol), SirfBin superset.  The default
   * factory setting is to communicate using NMEA.
   *
   * Since we are communicating using SPI and the gps chip is a SPI slave, it
   * can't send us unsolicited messages.   We always have to be talking to
   * the chip for it to talk to us.
   *
   * When the GPS is turned on, we first assume that it is has preserved its
   * running configuration which is OSP/SirfBin.
   *
   * The driver needs to function so as to keep the gps TX fifo (bytes coming to
   * the cpu) empty.  When the gps is powered up and configured to be sending messages
   * periodically, the cpu should be reading those messages fast enough to keep
   * the fifo empty.
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

  GPSC_START_DELAY,			// power on, waiting for gps to come up.
  GPSC_HUNT_1,				// Can we see them?
  GPSC_HUNT_2,
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


norace gpsc_state_t	    gpsc_state;			// low level collector state

/* instrumentation */
norace uint32_t		    gpsc_boot_time;		// time it took to boot.
norace uint32_t		    gpsc_cycle_time;		// time last cycle took
norace uint32_t		    gpsc_max_cycle;		// longest cycle time.
norace uint32_t		    t_gps_first_char;


module GPSP {
  provides {
    interface Init;
    interface StdControl as GPSControl;
    interface Boot as GPSBoot;
    interface Msp430SpiConfigure as SpiConfigure;
  }
  uses {
    interface Boot;
    interface Timer<TMilli> as GPSTimer;
    interface LocalTime<TMilli>;
    interface Hpl_MM_hw as HW;
    interface SpiBlock;
    interface Panic;
    interface GPSMsg;
    interface StdControl as GPSMsgControl;
    interface Trace;
    interface LogEvent;
    interface HplMsp430UsciA as Usci;
    interface Resource as UsciResource;
  }
}


implementation {

  norace uint32_t     t_gps_pwr_on;
  norace uint8_t      gpsc_reconfig_trys;
  norace bool	      gpsc_operational;		// if 0 then booting, do special stuff

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
    call Usci.disableIntr();

#ifndef GPS_LEAVE_UP
    call HW.gps_off();
#endif
    call GPSTimer.stop();
    call LogEvent.logEvent(DT_EVENT_GPS_OFF, 0);
    call GPSMsgControl.stop();
    gpsc_change_state(GPSC_OFF, GPSW_STOP);
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
	gpsc_boot_time = call LocalTime.get() - t_gps_pwr_on;
	call LogEvent.logEvent(DT_EVENT_GPS_BOOT_TIME, (uint16_t) gpsc_boot_time);
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

  async command const msp430_uart_union_config_t *UartConfigure.getConfig() {
    return &GPS_OP_SERIAL_CONFIG;
  }

  command error_t Init.init() {
    gpsc_change_state(GPSC_OFF, GPSW_NONE);
    gpsc_reconfig_trys = MAX_GPS_RECONFIG_TRYS;
    atomic {
      call UsciResource.immediateRequest();
      /*
       * default resource configure enables interrupts, turn them back off
       * Also flip the i/o pins back to input.   this is the default gps
       * off state.  No need to call disableIntr because the reset clears
       * all the enable bits.
       */
      call Usci.resetUsci(TRUE);
      call HW.gps_off();
    }
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
   * Currently running at 57600.  There was too much interrupt overhead when using
   * current interrupt stack and the Threads postAmble.  Losing bytes at 115200.
   * interarrival bytes time:  57600, 174 uS.   115200, 87 uS.  really simple
   * interrupt handler would do but there are a number of layers in the TinyOS
   * code and the Thread overhead just makes this worse.
   *
   * gps @ 4800, 4800: TTFC:  start up message length: 250 chars, 724 mis, 330 from gps power on
   *	first_char = 36 '$', char_count = 250, t_request = 394, t_pwr_on = 394,
   *	t_first_char = 724 (from gps power on 330 mis), t_eos = 1702 (delta (first) 978, from pwr_on 1308 mis)
   *	TTS: (nmea_go_sirf_bin, 26 bytes) 58 mis
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
   * 1) Turn the gps on.  The device won't start talking for about 300ms or so
   *    (note tinyos timers are in mis units).   We also want to give the gps
   *    enough time to recapture.
   * 2) can we immediately throw commands requesting the navigation data we want?
   * 3) can we send commands back to back?
   * 4) is it reliable?
   * 5) would it be better to sequence?
   *
   * Dedicated h/w.  No resource arbitration.
   */

  command error_t GPSControl.start() {
    if (gpsc_state != GPSC_OFF) {
      gps_warn(3, gpsc_state);
      return FAIL;
    }
    call LogEvent.logEvent(DT_EVENT_GPS_START, 0);
    call GPSMsgControl.start();
    t_gps_pwr_on = call LocalTime.get();
    call HW.gps_on();
    call Usci.setModeUart(&GPS_OP_SERIAL_CONFIG);

#ifdef GPS_RO
    if (gps_speed > 1)
      gps_speed = 1;
    if (ro > 1)
      ro = 0;
    if (ro) {
      gpsc_change_state(GPSC_ON, GPSW_START);
      call GPSTimer.stop();
      switch (gps_speed) {
	default:
	case 0:
	  call Usci.setModeUart(&sirf3_57600_serial_config);
	  call Usci.enableIntr();
	  return SUCCESS;
	case 1:
	  call Usci.setModeUart(&sirf3_4800_serial_config);
	  call Usci.enableIntr();
	  return SUCCESS;
      }
    }
#endif
    gpsc_change_state(GPSC_START_DELAY, GPSW_START);
    call GPSTimer.startOneShotAt(t_gps_pwr_on, DT_GPS_PWR_UP_DELAY);

    /*
     * While debugging we turn interrupts on.  The intent of start_delay however is to
     * allow the gps to be coming up without interrupts on so the cpu can sleep.
     */
    call Usci.enableIntr();
    return SUCCESS;
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
	t_gps_pwr_on = call LocalTime.get();
	call GPSTimer.startOneShotAt(t_gps_pwr_on, DT_GPS_PWR_UP_DELAY);
	call Usci.setModeUart(&sirf3_4800_serial_config);
	return;

      case GPSC_RECONFIG_4800_START_DELAY:
	gpsc_change_state(GPSC_RECONFIG_4800_HUNTING, GPSW_TIMER);
	call GPSTimer.startOneShot(DT_GPS_HUNT_LIMIT);
	call Usci.enableIntr();
	return;

      case GPSC_RECONFIG_4800_EOS_WAIT:
	gpsc_change_state(GPSC_RECONFIG_4800_SENDING, GPSW_TIMER);
	call GPSTimer.startOneShot(DT_GPS_SEND_TIME_OUT);
	if ((err = call UartStream.send(nmea_go_sirf_bin, sizeof(nmea_go_sirf_bin))))
	  call Panic.panic(PANIC_GPS, 10, err, gpsc_state, 0, 0);
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

	call Usci.disableIntr();		// going down, no interrupts while there

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
    if (!t_gps_first_char) {
      t_gps_first_char = call LocalTime.get();
      t_gps_first_char -= t_gps_pwr_on;
      nop();
    }

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
      case GPSC_START_DELAY:			/* could panic, but why bother */
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
	 * wait till all bytes have gone out.  The TI h/w provides a busy bit but
	 * this denotes either tx or rx is busy so we can't use it.  So shove one
	 * more byte out and wait for the TXBUF to go empty.
	 */
	call Usci.tx(0);
	while (!call Usci.isTxIntrPending()) ;
	call Usci.setModeUart(&GPS_OP_SERIAL_CONFIG);
	call Usci.enableIntr();
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
	call Usci.tx(0);
	while (!call Usci.isTxIntrPending()) ;
	call Usci.setModeUart(&sirf3_4800_serial_config);
	call Usci.enableIntr();
	break;

      default:
	gps_panic(14, gpsc_state);
	break;
    }
    return;
  }


  /*
   * GPS Message layer is signalling that we have arrived at a message
   * boundary.  Check to see if the h/w has been requested.
   */
  async event void GPSMsg.msgBoundary() {
  }

  async event void UartStream.receiveDone( uint8_t* buf, uint16_t len, error_t error ) { }

  event void UsciResource.granted() {
    nop();
  }
}
