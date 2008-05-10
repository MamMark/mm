/*
 * Copyright (c) 2008 Stanford University.
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
 * wiring by Kevin
 * @author Kevin Klues (klueska@cs.stanford.edu)
 *
 * code by Eric and Carl.
 * @author Eric B. Decker (cire831@gmail.com)
 * @author Carl W. Davis (carl@freeemf.org)
 */

#include "panic.h"
#include "gps.h"

module GPSByteCollectP {
  provides {
    interface Init;
    interface StdControl as GPSByteControl;
  }
  uses {
    interface Msp430TimerControl;
    interface Msp430Capture;
    interface Msp430Compare;
    interface HplMM3Adc as HW;
    interface Panic;
  }
}

implementation {
  enum {
    GPSB_OFF       = 1,
    GPSB_WAKEUP    = 2,
    GPSB_ON        = 3,
  };

  noinit uint8_t state;
  noinit uint8_t num_bits;
  noinit uint8_t build_byte;

  command error_t Init.init() {
    num_bits = 0;
    state = GPSB_OFF;
    return SUCCESS;
  }
  
  bool isSetSCCI() {
    //Bit 10 is the bit we want to check 0000 0000 0100 0000
    return ( TACCTL2 & SCCI ); 
  }

  command error_t GPSByteControl.start() {
    call HW.gps_on();
    state = GPSB_WAKEUP;

    /*
     * Start a delay timer.  When it goes off then do the following.
     */
    state = GPSB_ON;   
    atomic num_bits = 0;
    atomic build_byte = 0;
    
    //Set CCR into capture mode, FALSE = falling edge
    call Msp430TimerControl.setControlAsCapture(FALSE);
    call Msp430TimerControl.enableEvents();
    return SUCCESS;
  }

  command error_t GPSByteControl.stop() {
    call Msp430TimerControl.disableEvents();
    call HW.gps_off();
    state = GPSB_OFF;
    return SUCCESS;
  }
  
  async event void Msp430Capture.captured(uint16_t time) {

    //Switch to compare mode
    call Msp430TimerControl.setControlAsCompare();
    
    // The time at which this event occured is preserved in the 
    // CCR register so just add 1.5 bit times to that value
    call Msp430Compare.setEventFromPrev(GPS_4800_15_BITTIME);
  }
  
  async event void Msp430Compare.fired() {
    if(num_bits < 8) {
      num_bits++;
      build_byte >>= 1;
      if( isSetSCCI() )
	build_byte |= 0x80;
      call Msp430Compare.setEventFromPrev(GPS_4800_1_BITTIME);
    } else {
      if( !isSetSCCI() )
	call Panic.brk();
      num_bits = 0;
      call Msp430TimerControl.setControlAsCapture(FALSE);
    }
  }
}
