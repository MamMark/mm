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


uint8_t go_sirf_bin[] = {
  '$', 'P', 'S', 'R', 'F',	// header
  '1', '0', '0', ',',		// set serial port MID
  '0', ',',			// protocol SIRF binary
  '9', '6', '0', '0', ',',	// baud rate
  '8', ',',			// 8 data bits
  '1', ',',			// 1 stop bit
  '0',				// no parity
  '*', '0', '0',		// checksum
  '\r', '\n', 0			// terminator
};

#define SSIZE 1024

uint8_t sbuf[SSIZE];
uint32_t start_t0;
uint32_t end_time;
uint32_t diff;


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
    interface ResourceConfigure as SerialConfig;
    interface LocalTime<TMilli>;

    interface HplMsp430Usart as Usart;
  }
}

implementation {
  enum {
    GPS_UNINITILIZED = 1,
  };

  uint8_t gps_state;

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
      (void)snprintf(p, 5, "%02X\r\n", (unsigned int)sum);
    }
  }

  command error_t Init.init() {
    gps_state = GPS_UNINITILIZED;
    return SUCCESS;
  }

  command error_t GPSControl.start() {
    return call UARTResource.request();
  }

  command error_t GPSControl.stop() {
    return SUCCESS;
  }

  event void GpsTimer.fired() {
  }
  
  event void UARTResource.granted() {
    uint16_t i;
    bool timing;

    call Usart.disableIntr();	// for now we don't want them
    nmea_add_checksum(go_sirf_bin);
    IE2 = 0;
    timing = 1;
    mmP5out.ser_sel = SER_SEL_GPS;
    start_t0 = call LocalTime.get();
    call HW.gps_on();
//    uwait(1000);
    for (i = 0; i < SSIZE; i++) {
      while ((IFG2 & URXIFG1) == 0) ;
      sbuf[i] = U1RXBUF;
      if (timing) {
	timing = 0;
	end_time = call LocalTime.get();
	diff = end_time - start_t0;
      }
    }
    call HW.gps_off();
    mmP5out.ser_sel = SER_SEL_CRADLE;
    i = U1RXBUF;
    nop();
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

  msp430_uart_union_config_t gps_9600_serial_config = {
    {
       ubr:   UBR_4MHZ_9600,
       umctl: UMCTL_4MHZ_9600,
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
    return &gps_4800_serial_config;
  }
}
