/**
 * Copyright (c) 2010 Eric B. Decker
 * All rights reserved.
 *
 * Copyright (c) 2009 DEXMA SENSORS SL
 * All rights reserved.
 *
 * "Copyright (c) 2000-2003 The Regents of the University of California.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 *
 * - Neither the name of the DEXMA SENSORS SL, The University of California,
 *   nor the names of its contributors may be used to endorse or promote
 *   products derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE
 * DEXMA SENSORS SL, THE UNIVERSITY OF CALIFORNIA, OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 * OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
 * OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
 * BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE
 */

/**
 * @author Cory Sharp <cssharp@eecs.berkeley.edu>
 * @author Vlado Handziski <handzisk@tkn.tu-berlind.de>
 * @author Xavier Orduna <xorduna@dexmatech.com>
 * @author Eric B. Decker <cire831@gmail.com>
 *
 * Perform basic initilization for the clock subsystem on a msp430X (26xx)
 * family device.
 *
 * ACLK (Aux Clk) is assumed to be run off the LFXT interface (low-freq) at
 * 32KiHz (32768).
 *
 * MCLK (Main Clk) is run off the DCO (default 8 MHz) and is calibrated to
 * a 32KiHz (32768) crystal (ACLK).  DCO/1.
 *
 * SMCLK (sub-main clock) is run directly off the DCO 8 MHz.  DCO/1
 *
 * TimerA is programmed to for 1us ticks and is SMCLK/8.  This is the highest
 * divisor and if MCLK is cranked faster than 8 MHz either SMCLK can become
 * DCO/2 (which slows the peripherals down) or the timer subsystem is changed
 * to deal with a 500ns tick.
 *
 * It is intended that this version will become the default msp430x file in the
 * tinyos core tree.
 */

#include "Msp430DcoSpec.h"
#include "Msp430Timer.h"

module Msp430ClockP @safe() {
  provides interface Init;
  provides interface Msp430ClockInit;
}

implementation {
  MSP430REG_NORACE(IE1);
  MSP430REG_NORACE(TACTL);
  MSP430REG_NORACE(TAIV);
  MSP430REG_NORACE(TBCTL);
  MSP430REG_NORACE(TBIV);

  /*
   * TI sets DCO calibration information assuming decimal Hz.  This is reflected
   * in the baud rate tables for the UART speeds as well as the DCO clock values.
   *
   * To stay compatible with this we run the DCO calibration using decimal
   * Hz.  That way if someone wants to use the factory calib values they can
   * and we don't have to maintain two sets of baud rate tables.
   */
  enum {
    ACLK_CALIB_PERIOD = 8,
    TARGET_DCO_DELTA     = (TARGET_DCO_HZ   / ACLK_HZ)   * ACLK_CALIB_PERIOD,
  };

  command void Msp430ClockInit.defaultSetupDcoCalibrate() {
    TACTL   = TASSEL_2 | MC_2;		// SMCLK/1, continuous mode, everything else 0
    TBCTL   = TBSSEL_1 | MC_2;		// ACLK/1,  continuous

    /* calibrate changes just RSEL in BCSCTL1 so set up other bits the way
     * we want them.
     */
    BCSCTL1 = XT2OFF   | RSEL_MAX;	// set highest RSEL bit to start
    BCSCTL2 = 0;

    // leave BCSCTL3 alone

    TBCCTL0 = CM_1;			/* CM = 1, rising edge */
  }

  command void Msp430ClockInit.defaultInitClocks() {

#ifdef notdef
    /*
     * take a look at the factory defaults in the calib table.
     * These constants assume 3.0V @ 25C so aren't terribly
     * useful.  We still run the dco calibrator and we extract
     * the calibration values for just take a look.
     */
    if(CALBC1_8MHZ != 0xFF) {
      DCOCTL = 0x00;
      BCSCTL1 = CALBC1_8MHZ;                    //Set DCO to 8MHz
      DCOCTL = CALDCO_8MHZ;    
    } else { //start using reasonable values at 8 Mhz
      DCOCTL = 0x00;
      BCSCTL1 = 0x8D;
      DCOCTL = 0x88;
    }
#endif

    // BCSCTL1
    // .XT2OFF = 1;	disable external
    // .XTS = 0;	low freq mode for LFXT1
    // .DIVA = 0;	ACLK divisor 1
    // .RSEL, do not modify
    BCSCTL1 = XT2OFF | (BCSCTL1 & RSEL_MASK);

    // BCSCTL2
    // .SELM = 0; select DCOCLK as source for MCLK
    // .DIVM = 0; set the divisor of MCLK to 1
    // .SELS = 0; select DCOCLK as source for SCLK
    // .DIVS = 0; set the divisor of SCLK to 1
    // .DCOR = 0; select internal resistor for DCO
    BCSCTL2 = 0;

    // BCSCTL3: use default, on reset set to 4, 6pF.
	
    // IE1.OFIE = 0; no interrupt for oscillator fault
    CLR_FLAG(IE1, OFIE);
  }

  command void Msp430ClockInit.defaultInitTimerA() {
    TAR = 0;

    // TACTL
    // .TASSEL = 2;	source SMCLK = DCO/1
    // .ID = 3;		input divisor of 8
    // .MC = 0;		initially disabled
    // .TACLR = 0;
    // .TAIE = 1;	enable timer A interrupts
    TACTL = TASSEL_2 | ID_3 | TAIE;
  }

  command void Msp430ClockInit.defaultInitTimerB() {
    TBR = 0;

    // TBCTL
    // .TBCLGRP = 0;	each TBCL group latched independently
    // .CNTL = 0;	16-bit counter
    // .TBSSEL = 1;	source ACLK
    // .ID = 0;		input divisor of 1
    // .MC = 0;		initially disabled
    // .TBCLR = 0;
    // .TBIE = 1;	enable timer B interrupts
    TBCTL = TBSSEL_1 | TBIE;
  }

  default event void Msp430ClockInit.setupDcoCalibrate() {
    call Msp430ClockInit.defaultSetupDcoCalibrate();
  }
  
  default event void Msp430ClockInit.initClocks() {
    call Msp430ClockInit.defaultInitClocks();
  }

  default event void Msp430ClockInit.initTimerA() {
    call Msp430ClockInit.defaultInitTimerA();
  }

  default event void Msp430ClockInit.initTimerB() {
    call Msp430ClockInit.defaultInitTimerB();
  }

  void startTimerA() {
    // TACTL.MC = 2; continuous mode
    TACTL = MC_2 | (TACTL & ~(MC1 | MC0));
  }

  void stopTimerA() {
    //TACTL.MC = 0; stop timer A
    TACTL = TACTL & ~(MC1|MC0);
  }

  void startTimerB() {
    // TBCTL.MC = 2; continuous mode
    TBCTL = MC_2 | (TBCTL & ~(MC1|MC0));
  }

  void stopTimerB() {
    //TBCTL.MC = 0; stop timer B
    TBCTL = TBCTL & ~(MC1|MC0);
  }

  /*
   * dco calibration.
   *
   * dco calibration is done by looking at how many dco clocks via timerA fit
   * into some number of 32768 ACLK periods.  Since we don't know where in a
   * ACLK cycle we are, we must run two cycles.  The 2nd cycle is when we
   * actually do the measurement.
   *
   * Controls for the algorithm behaviour are:
   *
   * From tos/chips/msp430/timer/Msp430DcoSpec.h:
   *	TARGET_DCO_HZ		target dco frequency, 8000000
   *	ACLK_HZ			frequency of ACLK, 32768
   *
   *    ACLK_CALIB_PERIOD = 8,	how many aclk cycles to use for sample period.
   *    TARGET_DCO_DELTA	how many dco (ta) cycles we should see if
   *				calibrated.
   *
   * A calib control cell is passed around to control the algorithm.  This
   * control cell is the concatenation of RSEL (4 bits), DCOx (3 bits), and
   * MODx (5 bits).   Top byte contains RSEL, lower byte DCO and MOD.
   *
   * The key that drives this algorithm is TARGET_DCO_DELTA.  This is the value
   * we look for in a given ACLK_CALIB_PERIOD.  It is computed from
   * TARGET_DCO_HZ and ACLK_HZ.
   */

  void set_dco_calib(uint16_t calib) {
    BCSCTL1 = (BCSCTL1 & ~RSEL_MASK) | ((calib >> 8) & RSEL_MASK);
    DCOCTL  = calib & 0xff;
  }

  uint16_t test_calib_busywait_delta(uint16_t calib) {
    uint8_t  aclk_count = 2;
    uint16_t dco_prev   = 0;
    uint16_t dco_curr   = 0;

    set_dco_calib(calib);
    while( aclk_count-- > 0 ) {
      TBCCR0 = TBR + ACLK_CALIB_PERIOD;		// set next interrupt
      TBCCTL0 &= ~CCIFG;			// clear pending interrupt
      while((TBCCTL0 & CCIFG) == 0) {		// busy wait
      }
      dco_prev = dco_curr;
      dco_curr = TAR;
    }
    return dco_curr - dco_prev;
  }


  /*
   * busyCalibrateDCO
   *
   * With ACLK_CALIB_PERIOD of 8, takes ~6ms to calibrate.
   * This is only dependent on ACLK_CALIB_PERIOD and the clock rate of ACLK
   * which is most likely 32768.
   *
   * Tested for freqs >= 1MHz (1000000).  Does not seems to work for low
   * frequencies.  Probably because the counts aren't big enough.  But we
   * don't care.  4MHz is good, 8Mhz is good.  16MHz not tested yet.
   *
   * Returns with DCOCTL and BCSCTL1 set with appropriate values of DCO/MOD
   * and RSEL.
   */
  void busyCalibrateDco() {
    uint16_t calib;
    uint16_t step;

    // Binary search for RSEL,DCO,DCOMOD.
    
    for (calib = 0, step = RSEL_MAX << 8; step; step >>= 1) {
      // if step doesn't take us past the target, keep it
      if (test_calib_busywait_delta(calib | step) <= TARGET_DCO_DELTA)
        calib |= step;
      /*
       * if dco part is 7 then continuing mods don't do anything,  dco of 7
       * causes the h/w to ignore the mod bits.
       *
       * So once we hit dco 7, bail.
       */
      if ((calib & 0xe0) == 0xe0)
	break;
    }
    set_dco_calib(calib);
  }

  command error_t Init.init() {
    TACTL = TACLR;
    TAIV = 0;
    TBCTL = TBCLR;
    TBIV = 0;

    atomic {
      signal Msp430ClockInit.setupDcoCalibrate();
      busyCalibrateDco();
      signal Msp430ClockInit.initClocks();
      signal Msp430ClockInit.initTimerA();
      signal Msp430ClockInit.initTimerB();
      startTimerA();
      startTimerB();
    }
    return SUCCESS;
  }
}
