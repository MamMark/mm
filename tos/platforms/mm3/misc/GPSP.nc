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
 */

#define GPS_SPEED 115200

#include "panic.h"
#include "gps.h"


uint8_t nmea_go_sirf_bin[] = {
  '$', 'P', 'S', 'R', 'F',		// header
  '1', '0', '0', ',',			// set serial port MID
  '0', ',',				// protocol 0 SirfBinary 1 - NEMA
  '1', '1', '5', '2', '0', '0', ',',	// baud rate
  '8', ',',				// 8 data bits
  '1', ',',				// 1 stop bit
  '0',					// no parity
  '*', '0', '4',			// checksum
  '\r', '\n'				// terminator
};

#define SSIZE 2048

uint8_t sbuf[SSIZE];
norace uint16_t s_idx;
uint32_t t_send_start, t_send_done;
uint32_t t_diff;;
uint8_t rctl;

struct {
  uint8_t  do_send;
  uint8_t  first_err_rctl;
  uint8_t  first_char;
  uint16_t char_count;
  uint16_t first_err_count;
  uint32_t t_request;
  uint32_t t_pwr_on;
  uint32_t t_first_char;
  uint32_t t_last_char;
  uint32_t t_first_err;
  uint32_t t_end_of_startup;
} gpsp_inst;


module GPSP {
  provides {
    interface Init;
    interface StdControl as GpsControl;
    interface Msp430UartConfigure;
    interface Boot as GpsBoot;
  }
  uses {
    interface Boot;
    interface Resource as UARTResource;
    interface Timer<TMilli> as GpsTimer;
    interface LocalTime<TMilli>;
    interface HplMM3Adc as HW;
    interface UartStream;
    interface Panic;

    interface HplMsp430Usart as Usart;
  }
}

implementation {
  enum {
    GPS_FAIL = 1,
    GPS_OFF,
    GPS_PWR_ON_WAIT,
    GPS_RECONFIG,
    GPS_BOOT,
    GPS_REQUESTED,
    GPS_ON,
  };

  norace uint8_t gps_state;

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

  command error_t Init.init() {
    gps_state = GPS_OFF;
    nmea_add_checksum(nmea_go_sirf_bin);
    memset(sbuf, 0, sizeof(sbuf));
    s_idx = 0;
    return SUCCESS;
  }

  /*
   * Boot up the GPS.
   *
   * Previous components have completed boot, now it is GPS's turn.
   *
   * Start up strategy...
   *
   * The ET-312 sirfIII module has a battery pin and pwr.  The sirf chip will
   * maintain its last configuration settings as long as the battery input has
   * a reasonable amount of juice.  The pwr pin is brought up when we need
   * to have the GPS do its thing.  When powered the GPS first spews for awhile
   * with development information.  Then it settles down into issuing periodic
   * navigation results.
   *
   * If the tag runs out of power, the battery pin will no longer be supplied
   * and the GPS will revert to NMEA-4800-8N1.
   *
   * It takes approximately 300ms for the GPS to power up and start sending
   * data.  We want to set the GPS to SirfBinary at 115200.  We also set
   * various MID so it minimizes how much the chip talks.  We request specific
   * MIDs that give us the navigation information that we want.
   *
   * But if power has been maintained, the GPS will still be communicating in
   * sirfBinary at 115200.  So first we listen at 115200.  If we see framing
   * or other errors we switch to 4800 and switch over using the NMEA change
   * protocol message.
   *
   * The GPS bootstrap is performed once on system bring up.  Its purpose is
   * to perform the following steps:
   *
   * 1) Arbritrate for the UART (will also arbritrate for the underlying USART)
   * 2) Power the GPS up and set the UART for 115200.
   * 3) Listen for a packet (how long?)
   * 4) Send binary initializations, set up long report rates for MIDS, etc.
   *    We use explicit requests to get the information we want.
   *
   * 5) If we get overruns, framing errors, etc. then switch to 4800.
   * 6) repower to reset?
   * 7) wait for a NMEA 4800 packet.  how long?
   * 8) if we get a valid packet, send the switch to sirfBinary 115200
   * 9) wait for binary packet (goto 3).
   *
   * at 4800 NMEA, first char must be '$' (0x24, 36)
   * at 115200 binary, first char must be 0xa0 (sop is 0xa0a2)
   *
   * How long...
   *
   * gps @ 4800, uart 115200 time to first char...  when do overruns and rx errors occur.
   *	no characters received.  no errors.  got power on timeout.
   *
   * gps @ 115200, 115200, TTFC:  start up message length: 129 (time 107 mis), binary
   *	first_char = 160 (0xa0), char_count = 129, t_request = 386, t_pwr_on = 387,
   *	t_first_char = 701 (314 mis), t_last_char = 808, t_end_of_startup = 887 (timeout of 500 from power on)
   *	TTS: (nmea_go_sirf_bin, 26 bytes)  3 mis
   *
   * gps @ 4800, 4800: TTFC:  start up message length: 263 chars, 625 mis, 1053 from power on
   *	first_char = 36 '$', char_count = 263, t_request = 432, t_pwr_on = 433,
   *	t_first_char = 861 (428 mis), t_end_of_startup = 1486 (delta 625, from pwr_on 1053 mis)
   *	TTS: (nmea_go_sirf_bin, 26 bytes) 58 mis
   *
   * gps @ 115200, uart 4800:
   *	no characters received.  no errors.  get power on timeout.
   *
   * --------------------------------------------------------
   */

  event void Boot.booted() {
    signal GpsBoot.booted();
  }

  /*
   * Fire up the GPS.  We first request.  During the granting process
   * the GPS will be configured along with the USART used to talk to it.
   * During this process interrupts will be enabled and we should be
   * prepared to handle them even though we haven't gotten the grant back
   * yet (the arbiter configures then grants (which makes good sense)).
   *
   * Prior to seeing the grant the gps driver state (gps_state) will be
   * set to requesting.  After grant we take some time during which we
   * ignore the gps (takes about 300ms to power up).  gps_state is set
   * to GPS_PWR_WAIT.  After the delay, we run through the reset of GPS
   * power up.
   */
  command error_t GpsControl.start() {
    gps_state = GPS_REQUESTED;
    gpsp_inst.char_count = 0;
    gpsp_inst.first_err_count = 0;
    gpsp_inst.t_request = call LocalTime.get();
    return call UARTResource.request();
  }

  command error_t GpsControl.stop() {
    return SUCCESS;
  }


  /*
   * UARTResource.granted
   *
   * Called when the arbiter gives us control of the UART (also the underlying USART)
   * It will have already called the configurator which turns on the gps and sets the
   * serial mux to the gps.
   *
   * We start a timer (T_GPS_PWR_ON_TIME_OUT) during which time we are looking for the
   * first char transmitted from the GPS.  If we time out, assume wrong baud rate.  If
   * we don't receive what we are expecting (binary start 0xa0a2) then assume wrong baud
   * rate.
   */
  event void UARTResource.granted() {
    if (gps_state != GPS_REQUESTED) {
      call UARTResource.release();
      return;
    }
    gps_state = GPS_PWR_ON_WAIT;
    call GpsTimer.startOneShot(T_GPS_PWR_ON_TIME_OUT);
  }
  
  event void GpsTimer.fired() {
    if (!gpsp_inst.t_end_of_startup) {
      gpsp_inst.t_end_of_startup = call LocalTime.get();
    }
    call GpsTimer.startOneShot(5000);
    if (gpsp_inst.do_send) {
      t_send_start = call LocalTime.get();
      call UartStream.send(nmea_go_sirf_bin, sizeof(nmea_go_sirf_bin));
    }
  }
  
  async event void UartStream.sendDone( uint8_t* buf, uint16_t len, error_t error ) {
    t_send_done = call LocalTime.get();
    nop();
  }

  async event void UartStream.receivedByte( uint8_t byte ) {
    rctl = U1RCTL;
    if (gpsp_inst.char_count == 0) {
      gpsp_inst.t_first_char = call LocalTime.get();
      gpsp_inst.first_char = byte;
      nop();
    }
    if ((rctl & RXERR) && !gpsp_inst.first_err_rctl) {
      gpsp_inst.first_err_rctl = rctl;
      gpsp_inst.first_err_count = gpsp_inst.char_count;
      gpsp_inst.t_first_err = call LocalTime.get();
    }
    gpsp_inst.char_count++;
    gpsp_inst.t_last_char = call LocalTime.get();
    sbuf[s_idx++] = byte;
    if (s_idx == 1024)
      nop();
    if (s_idx >= SSIZE)
      s_idx = 0;
  }

  async event void UartStream.receiveDone( uint8_t* buf, uint16_t len, error_t error ) {
  }


//       ubr:   UBR_4MHZ_4800,
//       umctl: UMCTL_4MHZ_4800,


  const msp430_uart_union_config_t gps_115200_serial_config = {
    {
       ubr:   UBR_4MHZ_115200,
       umctl: UMCTL_4MHZ_115200,
       ssel: 0x02,		// smclk selected (DCO, 4MHz)
       pena: 0,			// no parity
       pev: 0,			// no parity
       spb: 0,			// one stop bit
       clen: 1,			// 8 bit data
       listen: 0,		// no loopback
       mm: 0,			// idle-line
       ckpl: 0,			// non-inverted clock
       urxse: 0,		// start edge off
       urxeie: 1,		// error interrupt enabled
       urxwie: 0,		// rx wake up disabled
       utxe : 1,		// tx interrupt enabled
       urxe : 1			// rx interrupt enabled
    }
  };


  /*
   * Called from witin the Usart configurator.
   *
   * We default to 115200 assuming that the gps most likely will have been powered
   * and properly configured after initial boot.
   */
  async command msp430_uart_union_config_t* Msp430UartConfigure.getConfig() {
    mmP5out.ser_sel = SER_SEL_GPS;
    call HW.gps_on();
    gpsp_inst.t_pwr_on = call LocalTime.get();
    return (msp430_uart_union_config_t*) &gps_115200_serial_config;
  }
}
