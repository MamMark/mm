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
  '*', '0', '0', '\r', '\n'	// terminator
}

module GPSP {
  provides {
    interface Init;
    interface StdControl as GPSControl;
  }
  uses {
    interface Panic;
    interface Timer<TMilli> as GpsTimer;
    interface HplMM3Adc as HW;
  }
}

implementation {

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
    return SUCCESS;
  }

  command error_t GPSControl.start() {
    call HW.gps_on();
    return SUCCESS;
  }

  command error_t GPSControl.stop() {
    return SUCCESS;
  }

  event void GpsTimer.fired() {
  }
}
