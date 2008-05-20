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

uint32_t gps_t0;
uint32_t gps_t1;

struct {
  uint16_t t1, t2, scci, cci;
} times[10];

module GPSByteCollectP {
  provides {
    interface Init;
    interface StdControl as GPSByteControl;
    interface GPSByte;
  }
  uses {
    interface Msp430TimerControl;
    interface Msp430Capture;
    interface Msp430Compare;
    interface Timer<TMilli> as GPSByteTimer;
    interface LocalTime<TMilli>;
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

    /*
     * Note: no need to turn the gps off.  PlatformInit does this when it
     * sets the default port pin settings.
     */
    num_bits = 0;
    state = GPSB_OFF;
    memset(times, 0, sizeof(times));
    return SUCCESS;
  }

  /*
   * check to see if the gps_rx bit is set from the last capture time.
   * SCCI is the synchronous captured bit.  Bit 10 (0x400)
   */

  bool isSetSCCI() {
    if (TACCTL2 & SCCI)
      return 1;
    else
      return 0;
    return ( (TACCTL2 & SCCI) == SCCI ); 
  }

  bool isSetCOV() {
    /*
     * Bit 2 indicates that a capture overflow occurred.
     * Somehow we missed the the actual start and we saw another
     * falling edge.  Not sure how to recover.  Probably turn
     * the thing off and restart.
     *
     * This should happen through a signal.
     */
    return ( TACCTL2 & COV ); 
  }

  command error_t GPSByteControl.start() {

    /*
     * this needs to get reworked.  The main gps module controls
     * arbitration and when power should come up etc.  This module
     * should get called by main gps and then enables the interrupt
     * and such.
     *
     * But for now we are just trying things out to figure out how
     * it works.
     */
    call HW.gps_on();
    call GPSByteTimer.startOneShot(GPS_PWR_ON_DELAY);
    gps_t0 = call LocalTime.get();
    state = GPSB_WAKEUP;
    return SUCCESS;
  }

  event void GPSByteTimer.fired() {
    state = GPSB_ON;   
    atomic {
      num_bits = 0;
      build_byte = 0;
    }
    
    /*
     * CM_2, 10 (2) falling,  01 (1) rising
     * CCIS_0 CCIxA (00)
     * SCS (synchronous)
     * CAP
     * CCIE (interrupt enabled)
     *
     *    call Msp430TimerControl.setControlAsCapture(FALSE);
     *    call Msp430TimerControl.enableEvents();
     */
    call Msp430TimerControl.setControlRaw(CM_2 | CCIS_0 | SCS | CAP | CCIE);
  }

  command error_t GPSByteControl.stop() {
    call Msp430TimerControl.disableEvents();
    call HW.gps_off();
    state = GPSB_OFF;
    return SUCCESS;
  }
  
  async event void Msp430Capture.captured(uint16_t time) {
    times[9].t1 = TACCR2;
    times[9].t2 = TAR;
    times[9].scci = TACCTL2 & SCCI;
    times[9].cci = TACCTL2 & CCI;
    gps_t1 = call LocalTime.get();

    /*
     * Note: setControlAsCompare makes assumptions about what
     * to stuff in particular fields.  Like the CCIS field.  (we
     * want CCIxA).
     *
     * We use setRaw to explicitly set what we need.  Make sure
     * we are staring at CCIxA.
     *
     * Switch to compare mode.  (setControlAsCompare disables CCIE)
     *
     *    call Msp430TimerControl.setControlAsCompare();
     *    call Msp430TimerControl.enableEvents();
     */

    call Msp430TimerControl.setControlRaw(CM_0 | CCIS_0 | SCS | CCIE);

    /*
     * The time at which this event occured is preserved in the 
     * CCR register so just add 1.5 bit times to that value
     *
     * We need to be careful here.  If interrupts have been disabled
     * for awhile then we could be behind the timer and won't interrupt
     * until TAR wraps.  Causing strange results.  Might want to check
     * for this.  But then what do we do?  Restart the gps?
     */
    call Msp430Compare.setEventFromPrev(GPS_4800_15_BITTIME);
  }
  
  async event void Msp430Compare.fired() {
    times[num_bits].t1 = TACCR2;
    times[num_bits].t2 = TAR;
    times[num_bits].scci = TACCTL2 & SCCI;
    times[num_bits].cci = TACCTL2 & CCI;
    if(num_bits < 8) {
      if (times[num_bits].scci) {
	if (!isSetSCCI())
	  nop();
      }
      num_bits++;
      build_byte >>= 1;
      if( TACCTL2 & SCCI )
	build_byte |= 0x80;
      call Msp430Compare.setEventFromPrev(GPS_4800_1_BITTIME);
    } else {
//      if( !(TACCTL2 & SCCI) )
//	call Panic.brk();
      num_bits = 0;
      signal GPSByte.byte_avail(build_byte);
      build_byte = 0;

      /*
       * Go back to looking for a start bit.  Capture mode.
       */
      call Msp430TimerControl.setControlRaw(CM_2 | CCIS_0 | SCS | CAP | CCIE);
    }
  }
}
