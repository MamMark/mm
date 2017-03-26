/*
 * Copyright (c) 2017 Daniel J. Maltbie, Eric B. Decker
 * All rights reserved.
 *
 * @author Daniel J. Maltbie (dmaltbie@daloma.org)
 * @date 26 Jan 2017
 * @author Eric B. Decker (cire831@gmail.com)
 * Various modifications
 */

#include <panic.h>
#include <platform_panic.h>
#include "gps.h"
#include "sirf.h"
#include "GPSMsgBuf.h"

#ifndef PANIC_GPS
enum {
  __pcode_gps = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_GPS __pcode_gps
#endif

/*
 * gps_check_table: list of supported configurations
 *
 * this table provides the list of supported configuration variations
 * that will be checked by the state machine as part of start up. Each
 * entry in the array may be tried before a valid configuration is
 * detected (by receiving a recognizable message). The first entry is
 * the target configuration, and is checked first in the assumption
 * that the chip has been previously configured.
 */
const gps_check_option_t gps_check_table[] = {
//  {1,4800,sizeof(nmea_set_9600),nmea_set_9600},
  {1,9600,sizeof(nmea_set_9600),nmea_set_9600},
//  {1,57600,sizeof(nmea_set_9600),nmea_set_9600},
//  {0,9600,sizeof(sirf_set_nmea),sirf_set_nmea},
//  {1,9600,sizeof(nmea_set_sirf_9600),nmea_set_sirf_9600},
//  {1,57600,sizeof(nmea_set_57600),nmea_set_57600},
//  {1,57600,sizeof(nmea_set_sirf_57600),nmea_set_sirf_57600},
};
const   uint8_t  gps_check_table_size = (sizeof(gps_check_table)/sizeof(gps_check_table[0]));
noinit uint32_t  gps_check_index;    // keeps track of which table entry to use
noinit uint16_t  gps_speed;          // current speed setting
noinit uint16_t  gps_check_success;  // number of successful msg checks

/*
 * gpsr_rx_state: current state of the receive byte processor to parse for msgs
 */
norace gpsr_rx_parse_state_t       gpsr_rx_state;

#ifdef GPS_LOG_EVENTS

typedef struct {
  uint32_t               ts;
  gpsr_rx_parse_state_t  state;
  gpsr_rx_parse_where_t  where;
  uint8_t                byte;
} rx_event_t;

#define        RX_MAX_EVENTS 256

rx_event_t     rx_evs[RX_MAX_EVENTS];
uint32_t       rx_nev;			// next rx event

#endif   // GPS_LOG_EVENTS

/*
 * number of failures tolerated before reset
 */
norace int32_t      gpsa_reconfig_trys;

module Gsd4eUActP {
  provides interface Gsd4eUAct as Act;
  uses {
    interface Gsd4eUHardware as HW;
    interface GPSBuffer;
    interface Platform;
    interface Panic;
  }
}
implementation {

/** Utility routines **/

  /* warn */
  void gps_warn(uint8_t where, parg_t p) {
    call Panic.warn(PANIC_GPS, where, p, 0, 0, 0);
  }

  /* panic */
  void gps_panic(uint8_t where, parg_t p) {
    call Panic.panic(PANIC_GPS, where, p, 0, 0, 0);
  }

  /* toggle gps on_off switch */
  void toggle_gps_on_off() {
    uint32_t t0;
    call HW.gps_set_on_off();
    t0 = call Platform.usecsRaw();
    while (call Platform.usecsRaw() - t0 < 105) ;
    call HW.gps_clr_on_off();
  }

  /*
   * gps_hibernate: switch off gps, check to see if it is already off first
   */
  void gps_hibernate() {
    uint32_t t0;
    if (call HW.gps_awake()) {
      toggle_gps_on_off();
      t0 = call Platform.usecsRaw();
      while (call Platform.usecsRaw() - t0 < DT_GPS_ON_OFF_PULSE_WIDTH) {
        if (!call HW.gps_awake()) return;
      }
      ROM_DEBUG_BREAK(0);
      return;
    }
  }

  /*
   * gps_hibernate: switch off gps, check to see if it is already off first
   */
  void gps_wakeup() {
    uint32_t t0;
    if (!call HW.gps_awake()) {
      toggle_gps_on_off();
      t0 = call Platform.usecsRaw();
      while (call Platform.usecsRaw() - t0 < DT_GPS_ON_OFF_PULSE_WIDTH) {
        if (call HW.gps_awake()) return;
      }
      ROM_DEBUG_BREAK(0);
      return;
    }
  }

  /*
   * switch on gps, check to see if it is already on first
   */
  void gps_reset() {
    uint32_t t0;
    call HW.gps_set_reset();
    t0 = call Platform.usecsRaw();
    while (call Platform.usecsRaw() - t0 < DT_GPS_RESET_PULSE_WIDTH) {
    }
    call HW.gps_clr_reset();
    return;
  }

  /*
   * change_check_speed: use current choice based on index, and update index for next time
   */
  void change_check_speed() {
    if (gps_check_index >= gps_check_table_size) {
      gps_warn(11, gps_check_index);
      gps_check_index = 0;
    }
    gps_speed = gps_check_table[gps_check_index].speed;
    call HW.gps_speed_di(gps_speed);               // change speed, disable rx ints
  }

  /*
   * gps_config_task: Handle messing with the timer on behalf of gps reconfigurations.
   */
  task void gps_config_task() {
    nop();
    nop();
    gps_check_success++;
  }

  /* add NMEA checksum to a possibly  *-terminated sentence */
  void add_nmea_checksum(uint8_t *sentence) {
    uint8_t sum = 0;
    uint8_t c, *p = sentence;

    nop();
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

  /* add sirf binary checksum */
  void add_sirf_bin_checksum(uint8_t *buf) {
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

  /* log state */
  void rx_log_state(uint8_t byte, gpsr_rx_parse_state_t next_state, gpsr_rx_parse_where_t where) {
#ifdef GPS_LOG_EVENTS
    uint8_t idx;

    atomic {
      idx = rx_nev++;
      if (rx_nev >= RX_MAX_EVENTS) {
        nop();
	rx_nev = 0;
      }
//      rx_evs[idx].ts = call LocalTime.get();
      rx_evs[idx].state = next_state;
      rx_evs[idx].where = where;
      rx_evs[idx].byte = byte;
#endif
    }
  }

/** ACTIONS **/

  /*
   * Act.gpsa_change_speed: change eUSCI UART to one of the expected values
   */
  command void Act.gpsa_change_speed() {
    if (--gpsa_reconfig_trys <= 0) {                         // countdown number of tries
      gps_warn(22, gpsa_reconfig_trys);
      gpsa_reconfig_trys = MAX_GPS_RECONFIG_TRYS * gps_check_table_size;
    }
    change_check_speed();                          // change to next speed to check
    signal Act.gpsa_poke_comm();
  }


  /*
   * Act.gpsa_checking: handle more recv bytes until message completed
   */
  async command void Act.gpsa_checking(uint8_t byte) {
    gpsr_rx_parse_where_t    where;

    nop();
    switch(byte) {
      case NMEA_START:                        // '$' start of EOM byte
        where = GPSR_NMEA_START;
        switch (gpsr_rx_state) {
          case GPSR_HUNT:                          // start of NMEA msg
            nop();
            call GPSBuffer.msg_start();
            call GPSBuffer.add_byte(byte);
            call GPSBuffer.begin_NMEA_SUM();
            gpsr_rx_state = GPSR_NMEA;
            break;
          case GPSR_NMEA:
            call GPSBuffer.msg_abort();
            gpsr_rx_state = GPSR_NMEA;
            break;
          case GPSR_NMEA_C1:
            call GPSBuffer.msg_abort();
            gpsr_rx_state = GPSR_NMEA;
            break;
          case GPSR_NMEA_C2:
            call GPSBuffer.msg_abort();
            gpsr_rx_state = GPSR_NMEA;
            break;
          case GPSR_SIRF:
            call GPSBuffer.add_byte(byte);
            break;
          case GPSR_SIRF_S1:
            gpsr_rx_state = GPSR_HUNT;
            break;
          case GPSR_SIRF_E1:
            call GPSBuffer.add_byte(byte);
            gpsr_rx_state = GPSR_SIRF;
            break;
          case GPSR_NONE:
            gps_panic(21, where);
            break;
        }
        break;

      case NMEA_END:                          // '*' NMEA EOM byte
        where = GPSR_NMEA_END;
        switch (gpsr_rx_state) {
          case GPSR_HUNT:
            break;
          case GPSR_NMEA:
            call GPSBuffer.end_SUM(0);
            call GPSBuffer.add_byte(byte); // add byte after ending checksum
            gpsr_rx_state = GPSR_NMEA_C1;
            break;
          case GPSR_NMEA_C1:
            gpsr_rx_state = GPSR_HUNT;
            break;
          case GPSR_NMEA_C2:
            gpsr_rx_state = GPSR_HUNT;
            break;
          case GPSR_SIRF:
            call GPSBuffer.add_byte(byte);
            break;
          case GPSR_SIRF_S1:
            gpsr_rx_state = GPSR_HUNT;
            break;
          case GPSR_SIRF_E1:
            call GPSBuffer.add_byte(byte);
            gpsr_rx_state = GPSR_SIRF;
            break;
          case GPSR_NONE:
            gps_panic(21, where);
            break;
        }
        break;

      case SIRF_BIN_A0:                            // first byte of sirf bin SOM
        where = GPSR_BIN_A0;
        switch (gpsr_rx_state) {
          case GPSR_HUNT:                          // start of sirf bin msg
            gpsr_rx_state = GPSR_SIRF_S1;
            break;
          case GPSR_NMEA:
            gpsr_rx_state = GPSR_HUNT;
            break;
          case GPSR_NMEA_C1:
            gpsr_rx_state = GPSR_HUNT;
            break;
          case GPSR_NMEA_C2:
            gpsr_rx_state = GPSR_HUNT;
            break;
          case GPSR_SIRF:
            call GPSBuffer.add_byte(byte);
            break;
          case GPSR_SIRF_S1:
            gpsr_rx_state = GPSR_HUNT;
            break;
          case GPSR_SIRF_E1:
            call GPSBuffer.add_byte(byte);
            gpsr_rx_state = GPSR_SIRF;
            break;
          case GPSR_NONE:
            gps_panic(21, where);
            break;
        }
        break;

      case SIRF_BIN_A2:                            // second byte of sirf bin SOM
        where = GPSR_BIN_A2;
        switch (gpsr_rx_state) {
          case GPSR_HUNT:
            break;
          case GPSR_NMEA:
            gpsr_rx_state = GPSR_HUNT;
            break;
          case GPSR_NMEA_C1:
            gpsr_rx_state = GPSR_HUNT;
            break;
          case GPSR_NMEA_C2:
            gpsr_rx_state = GPSR_HUNT;
            break;
          case GPSR_SIRF:
            call GPSBuffer.add_byte(byte);
            break;
          case GPSR_SIRF_S1:                       // sirf bin msg start
            call GPSBuffer.msg_start();
            call GPSBuffer.begin_SIRF_SUM();
            gpsr_rx_state = GPSR_SIRF;
            break;
          case GPSR_SIRF_E1:
            call GPSBuffer.add_byte(byte);
            gpsr_rx_state = GPSR_SIRF;
            break;
          case GPSR_NONE:
            gps_panic(21, where);
            break;
        }
        break;

      case SIRF_BIN_B0:                            // first byte of sirf bin EOM
        where = GPSR_BIN_B0;
        switch (gpsr_rx_state) {
          case GPSR_HUNT:
            break;
          case GPSR_NMEA:
            gpsr_rx_state = GPSR_HUNT;
            break;
          case GPSR_NMEA_C1:
            gpsr_rx_state = GPSR_HUNT;
            break;
          case GPSR_NMEA_C2:
            gpsr_rx_state = GPSR_HUNT;
            break;
          case GPSR_SIRF:
            call GPSBuffer.add_byte(byte);
            call GPSBuffer.end_SUM(-2);
            gpsr_rx_state = GPSR_SIRF_E1;
            break;
          case GPSR_SIRF_S1:
            gpsr_rx_state = GPSR_HUNT;
            break;
          case GPSR_SIRF_E1:
            call GPSBuffer.add_byte(byte);
            gpsr_rx_state = GPSR_SIRF;
            break;
          case GPSR_NONE:
            gps_panic(21, where);
            break;
        }
        break;

      case SIRF_BIN_B3:                            // second byte of sirf bin EOM
        where = GPSR_BIN_B3;
        switch (gpsr_rx_state) {
          case GPSR_HUNT:
            break;
          case GPSR_NMEA:
            gpsr_rx_state = GPSR_HUNT;
            break;
          case GPSR_NMEA_C1:
            gpsr_rx_state = GPSR_HUNT;
            break;
          case GPSR_NMEA_C2:
            gpsr_rx_state = GPSR_HUNT;
            break;
          case GPSR_SIRF:
            call GPSBuffer.add_byte(byte);
            break;
          case GPSR_SIRF_S1:
            gpsr_rx_state = GPSR_HUNT;
            break;
          case GPSR_SIRF_E1:                       // sirf bin msg end
            call GPSBuffer.msg_complete();
            gpsr_rx_state = GPSR_HUNT;
            break;
          case GPSR_NONE:
            gps_panic(21, where);
            break;
        }
        break;

      default:                                     // all other bytes
        where = GPSR_OTHER;
        switch (gpsr_rx_state) {
          case GPSR_HUNT:
            break;
          case GPSR_NMEA:
            // probably should add only ascii character
            call GPSBuffer.add_byte(byte);
            break;
          case GPSR_NMEA_C1:
            call GPSBuffer.add_byte(byte);         // first NMEA checksum byte
            gpsr_rx_state = GPSR_NMEA_C2;
            break;
          case GPSR_NMEA_C2:
            call GPSBuffer.add_byte(byte);         // second NMEA checksum byte
            call GPSBuffer.msg_complete();
            gpsr_rx_state = GPSR_HUNT;
            break;
          case GPSR_SIRF:
            call GPSBuffer.add_byte(byte);
            break;
          case GPSR_SIRF_S1:
            gpsr_rx_state = GPSR_HUNT;
            break;
          case GPSR_SIRF_E1:
            call GPSBuffer.add_byte(byte);
            gpsr_rx_state = GPSR_SIRF;
            break;
          case GPSR_NONE:
            gps_panic(21, where);
            break;
        }
        break;
    }
    if (where != GPSR_OTHER)
      rx_log_state(byte, gpsr_rx_state, where);
  }

  /*
   * Act.gpsa_checking: handle more recv bytes until message completed
   */
  async command void Act.gpsa_configing(uint8_t byte) {
    nop();
    post gps_config_task();
  }

  /*
   * Act.gpsa_checking: handle more recv bytes until message completed
   */
  async command void Act.gpsa_processing(uint8_t byte) {
    nop();
    post gps_config_task();
  }

  /*
   * Act.gpsa_ready: switch  gps chip to standby power.
   */
  command void Act.gpsa_ready() {
    nop();
    ROM_DEBUG_BREAK(0);
  }

  /*
   * Act.gpsa_recv_complete:
   */
  command void Act.gpsa_recv_complete() {
    nop();
    ROM_DEBUG_BREAK(0);
  }

  /*
   * Act.gpsa_reset_mode:
   */
  command void Act.gpsa_reset_mode() {
    call HW.gps_rx_int_disable();
    call HW.send_block_stop();
    signal Act.gpsa_stop_rx_timer();
    signal Act.gpsa_stop_tx_timer();
    gps_reset();
    signal Act.gpsa_start_tx_timer(DT_GPS_RESET_WAIT);  // reset takes a while
  }

  /*
   * Act.gpsa_sc_done: gps check msg has been sucessful, set up to receive gps msg(s)
   */
  command void Act.gpsa_sc_done() {
    signal Act.gpsa_stop_tx_timer();                         // stop transmit timer
    call HW.gps_tx_finnish();                                // flush transmit buffer
    gpsr_rx_state = GPSR_HUNT;                               // reset receive msg parser
    call GPSBuffer.msg_abort();                              // re-start msg buffer 
    call HW.gps_rx_int_enable();                             // start listening for gps bytes
    signal Act.gpsa_start_rx_timer(DT_GPS_RECV_CHECK_WAIT);  // start receive timer
    signal Act.gpsa_start_tx_timer(DT_GPS_CYCLE_CHECK_WAIT); // start transmit timer
  }

  /*
   * Act.gpsa_send_check:
   */
  command void Act.gpsa_send_check() {
    uint8_t          mode = gps_check_table[gps_check_index].mode;
    uint8_t          *msg = gps_check_table[gps_check_index].msg;
    uint32_t          len = gps_check_table[gps_check_index].len;

    call HW.send_block_stop();                                  // clear previous send
    if (mode) add_nmea_checksum(msg);
    else      add_sirf_bin_checksum(msg);
    call HW.send_block(msg, len);
    if (++gps_check_index >= gps_check_table_size) {            // advance the index for next time
      gps_check_index = 0;
    }
    signal Act.gpsa_start_tx_timer(DT_GPS_SEND_CHECK_WAIT);     // time to wait for tx done
  }

  /*
   * Act.gpsa_send_complete: handle send completion
   */
  command void Act.gpsa_send_complete() {
    nop();
    post gps_config_task();
  }

  /*
   * Act.gpsa_send_error:
   */
  command void Act.gpsa_send_error() {
    nop();
    ROM_DEBUG_BREAK(0);
  }

  /*
   * Act.gpsa_set_asleep: switch gps chip to standby power.
   */
  command void Act.gpsa_set_asleep() {
    if (gpsc_state == GPSC_OFF) {
      gps_warn(15, gpsc_state);
      return;
    }
    gps_hibernate();
    call HW.gps_rx_int_disable();
    signal Act.gpsa_stop_rx_timer();
    signal Act.gpsa_stop_tx_timer();
  }

  /*
   * Act.gpsa_set_awake: wake up gps chip and start to listen for messages.
   */
  command void Act.gpsa_set_awake() {
    gps_wakeup();                                          // make sure gps is awake
    gps_check_index = 0;                                   // begin with first check table entry
    change_check_speed();                                  // sets speed based on check_index
    signal Act.gpsa_start_tx_timer(DT_GPS_WAKE_UP_DELAY);  // don't wait forever
  }

  /*
   * Act.gpsa_start: awaken the GPS chip
   */
  command void Act.gpsa_start() {
    // to start, we assume gps is already operating which will be verified
    // in future states. for now we just need to set our eUSCI UART speed
    gpsa_reconfig_trys = MAX_GPS_RECONFIG_TRYS * gps_check_table_size;
    gps_check_success = 0;
//    signal Act.gpsa_poke_comm();       // handle further actions in separate task
    gps_reset();
    signal Act.gpsa_start_tx_timer(DT_GPS_WAKE_UP_DELAY);  // don't wait forever
  }

  /*
   * Act.gpsa_start_config: start sending configuration message to the GPS chip
   */
  command void Act.gpsa_start_config() {
    nop();
    ROM_DEBUG_BREAK(0);
    call HW.gps_tx_finnish();                              // flush transmit buffer
    signal Act.gpsa_stop_tx_timer();                       // stop transmit timer
    call HW.gps_rx_int_enable();
    post gps_config_task();
  }

  /*
   * Act.gpsa_stop: put the GPS chip into hibernation mode
   */
  command void Act.gpsa_stop() {
  }

/** hardware related events **/

  /*
   * HW.byte_avail
   */
  async event void HW.byte_avail(uint8_t byte) {
    signal Act.gpsa_process_byte(byte);
  }


  async event void HW.send_block_done(uint8_t* ptr, uint16_t len, error_t error) {
    signal Act.gpsa_send_done(ptr, len, error);
  }


  async event void HW.receive_block_done(uint8_t *ptr, uint16_t len, error_t err) { }


  async event void Panic.hook() { }
}
