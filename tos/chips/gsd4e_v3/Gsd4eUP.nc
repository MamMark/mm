/*
 * Copyright (c) 2008-2010, 2017 Eric B. Decker, Daniel J. Maltbie
 * All rights reserved.
 *
 * @author Eric B. Decker (cire831@gmail.com)
 * @author Daniel J. Maltbie (dmaltbie@daloma.org)
 * @date 28 May 2008
 *
 * Dedicated usci uart port.
 * refactored 1/26/2017 for mm6a, dev6a, port abstraction
 * originally based on UART sirf3 driver.  rewritten for
 * SirfStarIV using UART and Port abstraction.
 */

#include <panic.h>
#include <platform_panic.h>
#include "gps.h"
#include "sirf.h"

#ifndef PANIC_GPS
enum {
  __pcode_gps = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_GPS __pcode_gps
#endif

/*
 * State Machine Description
 */
/*** insert here ***/

/*
 * gpsc_state: current state of the driver state machine
 */
norace gpsc_state_t	    gpsc_state;

/* instrumentation */
norace uint32_t		    gpsc_boot_time;		// time it took to boot.
norace uint32_t		    gpsc_cycle_time;		// time last cycle took
norace uint32_t		    gpsc_max_cycle;		// longest cycle time.
norace uint32_t		    t_gps_first_char;

#ifdef GPS_EAVESDROP
#define GPS_EAVES_SIZE 2048

norace uint8_t gbuf[GPS_EAVES_SIZE];
norace uint16_t g_idx;
#endif

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

#endif   // GPS_LOG_EVENTS

/*
 * Gsd4eUP - module implementation
 */
module Gsd4eUP {
  provides {
    interface Init;
    interface StdControl as GPSControl;
    interface Boot as GPSBoot;
  }
  uses {
    interface Boot;

    interface Gsd4eUAct as Act;

    interface Timer<TMilli> as GPSTxTimer;
    interface Timer<TMilli> as GPSRxTimer;
    interface LocalTime<TMilli>;

    interface Trace;
    interface Panic;
#ifdef notdef
    interface LogEvent;
#endif
  }
}
implementation {

  norace uint32_t     t_gps_pwr_on;             // when driver started
  norace bool	      gpsc_operational;		// if 0 then booting, do special stuff

  /* log state */
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

  /* gpsc_change_state: change state */
  event void Act.gpsa_change_state(gpsc_state_t next_state, gps_where_t where) {
    gpsc_change_state(next_state, where);
  }

  /* gpsc_get_state: return current state */
  event gpsc_state_t Act.gpsa_get_state() {
    return gpsc_state;
  }

  /* gpsc_start_tx_timer: start the gps transmit timer */
  event void Act.gpsa_start_tx_timer(uint32_t t) {
    call GPSTxTimer.startOneShot(t);
  }

  /* gpsc_stop_tx_timer: stop the gps transmit timer */
  event void Act.gpsa_stop_tx_timer() {
    call GPSTxTimer.stop();
  }

  /* gpsc_start_rx_timer: start the gps receive timer */
  event void Act.gpsa_start_rx_timer(uint32_t t) {
    call GPSRxTimer.startOneShot(t);
  }

  /* gpsc_stop_rx_timer: stop the gps receive timer */
  event void Act.gpsa_stop_rx_timer() {
    call GPSRxTimer.stop();
  }

  /* warn */
  void gps_warn(uint8_t where, parg_t p) {
    call Panic.warn(PANIC_GPS, where, p, 0, 0, 0);
  }

  /* panic */
  void gps_panic(uint8_t where, parg_t p) {
    call Panic.panic(PANIC_GPS, where, p, 0, 0, 0);
  }
  /*
   * Init.init: initialize gps driver
   */
  command error_t Init.init() {
//    call LogEvent.logEvent(DT_EVENT_GPS_Init,0);
    gpsc_state = GPSC_OFF;  // ensure driver state is set to off (not zero).
    return SUCCESS;
  }

  /*
   * Boot.booted:
   */
  event void Boot.booted() {
//    call LogEvent.logEvent(DT_EVENT_GPS_BOOT,0);
  }

  /*
   * GPSControl.start: start up the gps receiver chip
   */
  command error_t GPSControl.start() {
    if (gpsc_state != GPSC_OFF) {
      gps_warn(3, gpsc_state);
      return FAIL;
    }
//    call LogEvent.logEvent(DT_EVENT_GPS_START, 0);
    t_gps_pwr_on = call LocalTime.get();
    call Act.gpsa_start();
    gpsc_change_state(GPSC_WAKING, GPSW_START);
    return SUCCESS;
  }

  /*
   * GPSControl.stop: Stop all GPS activity.
   *
   * If we have requested but not yet been granted and stop is called
   * not to worry.  When the grant occurs, our state being OFF will
   * cause an immediate release.
   */
  command error_t GPSControl.stop() {
    call Act.gpsa_set_asleep();
    gpsc_change_state(GPSC_OFF, GPSW_STOP);
    return SUCCESS;
  }

  /*
   * comm_task
   */
  task void comm_task() {
    gpsc_state_t next_state, cur_gps_state;

    atomic cur_gps_state = gpsc_state;
    next_state = cur_gps_state;
    switch(cur_gps_state) {

      case GPSC_WAKING:
        call Act.gpsa_set_awake();
        next_state = GPSC_SEND_CHECK;
	break;

      case GPSC_SEND_CHECK:
        call Act.gpsa_send_check();
        next_state = GPSC_SC_WAIT;
        break;

      case GPSC_SC_WAIT:
        call Act.gpsa_reset_mode();
        next_state = GPSC_WAKING;
        break;

      case GPSC_CHECKING:
        call Act.gpsa_start_config();
        next_state = GPSC_CONFIGING;
	break;

      case GPSC_CONFIGING:
        call Act.gpsa_ready();
        next_state = GPSC_ON;
	break;

      case GPSC_RECEIVING:
        call Act.gpsa_recv_complete();
        next_state = GPSC_ON;

      default:
        gps_panic(9, gpsc_state);
	nop();
        break;
    }
    gpsc_change_state(next_state, GPSW_COMM_TASK);
  }

  /*
   * GPSRxTimer.fired - handle transmit state machine related timeouts
   */
  event void GPSTxTimer.fired() {
    gpsc_state_t next_state, cur_gps_state;

    atomic cur_gps_state = gpsc_state;
    next_state = cur_gps_state;
    switch (cur_gps_state) {

      case GPSC_WAKING:
        call Act.gpsa_set_awake();
        next_state = GPSC_SEND_CHECK;
	break;

      case GPSC_SEND_CHECK:
        call Act.gpsa_send_check();
        next_state = GPSC_SC_WAIT;
        break;

      case GPSC_SC_WAIT:
        call Act.gpsa_change_speed();
        next_state = GPSC_SEND_CHECK;
        post comm_task();
        break;

      case GPSC_CHECKING:
        call Act.gpsa_reset_mode();
        next_state = GPSC_WAKING;
	break;

      case GPSC_CONFIGING:
        call Act.gpsa_set_asleep();
        next_state = GPSC_WAKING;
        // may decide to add reset here if too many tries at checking
        break;

      case GPSC_ON:
      case GPSC_RECEIVING:
        call Act.gpsa_send_error();
        break;

      default:
	gps_panic(8, gpsc_state);
	nop();
	break;
    }
    gpsc_change_state(next_state, GPSW_TX_TIMER);
  }

  /*
   * GPSRxTimer.fired - handle receive state machine related timeouts
   */
  event void GPSRxTimer.fired() {
    gpsc_state_t next_state, cur_gps_state;

    atomic cur_gps_state = gpsc_state;
    next_state = cur_gps_state;
    switch (cur_gps_state) {

      case GPSC_CHECKING:
        call Act.gpsa_change_speed();
        next_state = GPSC_SEND_CHECK;
        post comm_task();
        break;

      case GPSC_CONFIG:
        call Act.gpsa_reset_mode();
        next_state = GPSC_WAKING;
        post comm_task();
        break;

      case GPSC_CONFIGING:
        call Act.gpsa_set_asleep();
        next_state = GPSC_WAKING;
        // may decide to add reset here if too many tries at checking
        break;

      case GPSC_ON:
      case GPSC_RECEIVING:
        call Act.gpsa_ready();
        next_state = GPSC_ON;
        break;

      default:
	gps_panic(7, gpsc_state);
	nop();
	break;
    }
    gpsc_change_state(next_state, GPSW_RX_TIMER);
  }

  /*
   * Act.gpsa_process_byte
   */
  async event void Act.gpsa_process_byte(uint8_t byte) {
    gpsc_state_t next_state, cur_gps_state;

#ifdef GPS_EAVESDROP
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
#endif

    atomic cur_gps_state = gpsc_state;
    next_state = cur_gps_state;
    switch(cur_gps_state) {
      case GPSC_CHECKING:
        call Act.gpsa_checking(byte);
        next_state = GPSC_CHECKING;
        break;

      case GPSC_CONFIGING:
        call Act.gpsa_configing(byte);
        next_state = GPSC_CONFIGING;
        break;

      case GPSC_ON:
        call Act.gpsa_processing(byte);
        next_state = GPSC_ON;
        break;

      case GPSC_RECEIVING:
        call Act.gpsa_processing(byte);
        next_state = GPSC_RECEIVING;
        break;

      default:
       // gps_panic(6, gpsc_state);
	nop();
        break;
    }
    gpsc_change_state(next_state, GPSW_RX_BYTE);
  }

  /*
   * send_task
   */
  task void send_task() {
    gpsc_state_t next_state, cur_gps_state;

    atomic cur_gps_state = gpsc_state;
    next_state = cur_gps_state;
    switch(cur_gps_state) {
      case GPSC_SC_WAIT:
        call Act.gpsa_sc_done();
        next_state = GPSC_CHECKING;
        break;

      case GPSC_ON:
      case GPSC_RECEIVING:
        call Act.gpsa_send_complete();
        next_state = GPSC_ON;
	break;

      default:
	gps_panic(5, gpsc_state);
	break;
    }
    gpsc_change_state(next_state, GPSW_SEND_DONE);
  }

  /*
   * Act.gpsa_poke_comm
   */
  event void Act.gpsa_poke_comm() {
    post comm_task();
  }

  /*
   * Act.gpsa_send_done
   */
  async event void Act.gpsa_send_done(uint8_t* ptr, uint16_t len, error_t error) {
    post send_task();
  }

  /*
   * Panic.hook
   */
  async event void Panic.hook() { }
}
