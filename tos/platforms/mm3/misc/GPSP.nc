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

#include "panic.h"
#include "gps.h"


//  '5', '7', '6', '0', '0', ',',	// baud rate
//  '*', '3', '7',		// checksum

uint8_t go_sirf_bin[] = {
  '$', 'P', 'S', 'R', 'F',	// header
  '1', '0', '0', ',',		// set serial port MID
  '0', ',',			// protocol SIRF binary
  '4', '8', '0', '0', ',',	// baud rate
  '8', ',',			// 8 data bits
  '1', ',',			// 1 stop bit
  '0',				// no parity
  '*', '0', 'F',		// checksum
  '\r', '\n', 0			// terminator
};

#define OFF_TIME 100
#define ON_TIME 5

#define SSIZE 2048

uint8_t sbuf[SSIZE];
norace uint16_t s_idx;
norace uint32_t t_t0;
norace uint32_t t_first_char;
norace uint32_t t_send_done;
norace uint32_t t_first_binary;
uint32_t diff_first_char;;
uint32_t diff_first_binary;;
norace uint8_t t_state;


enum {
  TS_0 = 0,
  TS_FIRST_CHAR = 1,
  TS_NEXT_CHAR = 2,
  TS_FIRST_BINARY = 3,
};

module GPSP {
  provides {
    interface Init;
    interface StdControl as GPSControl;
    interface Msp430UartConfigure;
  }
  uses {
    interface Resource as UARTResource;
    interface Panic;
    interface Timer<TMilli> as GpsTimer;
    interface HplMM3Adc as HW;
    interface LocalTime<TMilli>;
    interface UartStream;

    interface HplMsp430Usart as Usart;
  }
}

implementation {
  enum {
    GPS_FAIL = 1,
    GPS_OFF,
    GPS_TRY_4800,
    GPS_TRY_57600,
    GPS_UNINITILIZED,
    GPS_RXTX,
  };

  norace uint8_t gps_state;

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
#endif

  command error_t Init.init() {
    return SUCCESS;
  }

  command error_t GPSControl.start() {
#ifdef LOOP_GPS_PWR
    call HW.gps_off();
    t_state = 0;
    call GpsTimer.startOneShot(OFF_TIME);
    return SUCCESS;
#endif
    memset(sbuf, 0, sizeof(sbuf));
    gps_state = GPS_OFF;
    s_idx = 0;
    t_state = TS_0;
    return call UARTResource.request();
  }

  command error_t GPSControl.stop() {
    return SUCCESS;
  }

  event void GpsTimer.fired() {
    nop();
#ifdef LOOP_GPS_PWR
    if (t_state) {
      t_state = 0;
      call HW.gps_off();
      call GpsTimer.startOneShot(OFF_TIME);
      return;
    }
    t_state = 1;
    call HW.gps_on();
    call GpsTimer.startOneShot(ON_TIME);
    return;
#else
    call HW.gps_off();
    gps_state = GPS_OFF;
    call UARTResource.release();
#endif    
  }
  
  event void UARTResource.granted() {
    t_state = TS_FIRST_CHAR;
    t_t0 = call LocalTime.get();
    call HW.gps_on();
    gps_state = GPS_RXTX;
    call GpsTimer.startOneShot(10000);
  }
  
  async event void UartStream.sendDone( uint8_t* buf, uint16_t len, error_t error ) {
    t_send_done = call LocalTime.get();
    t_state = TS_FIRST_BINARY;
  }

  async event void UartStream.receivedByte( uint8_t byte ) {
    if (gps_state != GPS_RXTX) {
      nop();
      t_state++;
      t_state--;
      return;
    }
    switch(t_state) {
      case TS_0:
      default:
	break;
      case TS_FIRST_CHAR:
	t_first_char = call LocalTime.get();
	diff_first_char = t_first_char - t_t0;
	call UartStream.send(go_sirf_bin, sizeof(go_sirf_bin));
	t_state = TS_NEXT_CHAR;
	break;
      case TS_FIRST_BINARY:
	t_first_binary = call LocalTime.get();
	diff_first_binary = t_first_binary - t_first_char;
	t_state = TS_0;
	break;
    }
    if (s_idx >= SSIZE)
      return;
    sbuf[s_idx++] = byte;
    if (s_idx >= 1024)
      nop();
  }

  async event void UartStream.receiveDone( uint8_t* buf, uint16_t len, error_t error ) {
  }

  msp430_uart_union_config_t gps_4800_serial_config = {
    {
       ubr:   UBR_4MHZ_4800,
       umctl: UMCTL_4MHZ_4800,
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

  msp430_uart_union_config_t gps_57600_serial_config = {
    {
       ubr:   UBR_4MHZ_57600,
       umctl: UMCTL_4MHZ_57600,
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


  async command msp430_uart_union_config_t* Msp430UartConfigure.getConfig() {
    /*
     * this is called from within the usart configurator so will have
     * the desired effect.
     */
//    mmP5out.ser_sel = SER_SEL_GPS;
    mmP5out.ser_sel = SER_SEL_CRADLE;
    return &gps_4800_serial_config;
  }
}
