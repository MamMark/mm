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
      build_byte <<= 1;
      if( isSetSCCI() ) build_byte += 1;
      call Msp430Compare.setEventFromPrev(GPS_4800_1_BITTIME);
    }
    else {
      if( !isSetSCCI() ) call Panic.brk();
      num_bits = 0;
      call Msp430TimerControl.setControlAsCapture(FALSE);
    }
  }
}
























#if FALSE
  enum {
    GPSB_OFF       = 1,
    GPSB_DELAY     = 2,
    GPSB_START_BIT = 3,
    GPSB_DATA      = 4,
    GPSB_STOP      = 5,
  };

  noinit uint8_t state;
  noinit uint8_t bit;
  noinit uint8_t build_byte;


  command error_t Init.init() {
    bit = 0;
    state = GPSB_OFF;
    return SUCCESS;
  }

  command error_t GPSByteControl.start() {
    call HW.gps_on();
    state = GPSB_DELAY;

    /*
     * Start a delay timer.  When it goes off then enable the interrupt.
     */
    call gpsRxInt.enableFallingEdge();
    build_byte = 0;
    return SUCCESS;
  }

  command error_t GPSByteControl.stop() {
    call gpsRxInt.disable();
    call HW.gps_off();
    state = GPSB_OFF;
    return SUCCESS;
  }

  event void BitTimer.fired() {
    uint8_t new_bit;
    
    /*
     * As bits are coming in, the high order bit in build_byte will be set
     * if the input pin is set.  Build_byte is shifted right after each bit.
     * after 7 shifts the first bit which was in the high order will be in
     * the low order.
     */

    new_bit = call gpsRx.get();
    if (bit > 7) {
      /*
       * doing stop bit.  check and finish up
       * hand byte built to next layer.
       *
       * re-enable the interrupt
       */
      call gpsRxInt.enableFallingEdge();
//    signal GPSByte.byte_avail(build_byte);
      state = GPSB_START_BIT;
      if (new_bit == 0)
	call Panic.warn(PANIC_MISC, 2, new_bit, 0, 0, 0);
      return;
    }
    build_byte >>= 1;
    if (new_bit)
      build_byte |= 0x80;
    bit++;
    call BitTimer.startOneShot(GPS_1_BITTIME);
  }

  async event void gpsRxInt.fired() {
    uint8_t *bp;

    call gpsRxInt.disable();

    call BitTimer.startOneShot(GPS_15_BITTIME);
    state = GPSB_DATA;
    bit = 0;
    return;


    bp = Xtemp;
    *(bp++) = call gpsRx.get();
    while (call gpsRx.get()) {
      nop();
    }
    *(bp++) = call gpsRx.get();
    uwait(109);
    *(bp++) = call gpsRx.get();
    uwait(105);
    *(bp++) = call gpsRx.get();
    *(bp++) = call gpsRx.get();
    *(bp++) = call gpsRx.get();
    *(bp++) = call gpsRx.get();
    *(bp++) = call gpsRx.get();
    *(bp++) = call gpsRx.get();
    *(bp++) = call gpsRx.get();
    *(bp++) = call gpsRx.get();
    *(bp++) = call gpsRx.get();
    *(bp++) = call gpsRx.get();
    *(bp++) = call gpsRx.get();
    *(bp++) = call gpsRx.get();
    *(bp++) = call gpsRx.get();
    *(bp++) = call gpsRx.get();
    *(bp++) = call gpsRx.get();
    *(bp++) = call gpsRx.get();
    *(bp++) = call gpsRx.get();
    *(bp++) = call gpsRx.get();
    *(bp++) = call gpsRx.get();
    *(bp++) = call gpsRx.get();
    *(bp++) = call gpsRx.get();
    *(bp++) = call gpsRx.get();
    *(bp++) = call gpsRx.get();
    *(bp++) = call gpsRx.get();
    *(bp++) = call gpsRx.get();
    *(bp++) = call gpsRx.get();
    *(bp++) = call gpsRx.get();
    *(bp++) = call gpsRx.get();
    nop();
  }
#endif
