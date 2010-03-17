/**
 *
 * Copyright 2010 (c) Eric B. Decker
 * All rights reserved.
 *
 * Warning: many of these routines directly touch cpu registers
 * it is assumed that this is initilization code and interrupts are
 * off.
 *
 * @author Eric B. Decker
 */

#include "hardware.h"

#ifdef notdef

#define STUFF_SIZE 32

noinit struct {
  uint8_t dcoctl;
  uint8_t bcsctl1;
  uint8_t bcsctl2;
  uint8_t bcsctl3;
} stuff[STUFF_SIZE];

noinit bool clear_stuff;
noinit uint16_t nxt;

void set_stuff() {
  if (clear_stuff) {
    memset(stuff, 0, sizeof(stuff));
    clear_stuff = 0;
    nxt = 0;
  }
  if (nxt >= STUFF_SIZE)
    nxt = 0;
  stuff[nxt].dcoctl  = DCOCTL;
  stuff[nxt].bcsctl1 = BCSCTL1;
  stuff[nxt].bcsctl2 = BCSCTL2;
  stuff[nxt].bcsctl3 = BCSCTL3;
  nxt++;
}

#endif


module PlatformP{
  provides {
    interface Init;
    interface GeneralIO as Led2;
  }
  uses {
    interface Init as ClockInit;
    interface Init as LedsInit;
    interface Msp430ClockInit;
  }
}

implementation {

  /*
   * We assume that the clock system after reset has been
   * set to some reasonable value.  ie ~1MHz.  We assume that
   * all the selects are 0, ie.  DIVA/1, XTS 0, XT2OFF, SELM 0,
   * DIVM/1, SELS 0, DIVS/1.  MCLK <- DCO, SMCLK <- DCO,
   * LFXT1S 32768, XCAP ~6pf
   *
   * We wait about a second for the 32KHz to stablize.
   *
   * PWR_UP_SEC is the number of times we need to wait for
   * TimerA to cycle (16 bits) when clocked at the default
   * msp430f2618 dco (about 1 MHz).
   */

#define PWR_UP_SEC 16

  void wait_for_32K() __attribute__ ((noinline)) {
    uint16_t left;

    TACTL = TACLR;			// also zeros out control bits
    TAIV = 0;
    TBCTL = TBCLR;
    TBIV = 0;
    TACTL = TASSEL_2 | MC_2;		// SMCLK/1, continuous
    TBCTL = TBSSEL_1 | MC_2;		//  ACLK/1, continuous
    TBCCTL0 = 0;

    /*
     * wait for about a sec for the 32KHz to come up and
     * stabilize.  We are guessing that it is stable and
     * on frequency after about a second but this needs
     * to be verified.
     *
     * FIX ME.  Need to verify stability of 32KHz.  It definitely
     * has a good looking waveform but what about its frequency
     * stability.  Needs to be measured.
     */
    left = PWR_UP_SEC;
    while (1) {
      if (TACTL & TAIFG) {
	/*
	 * wrapped, clear IFG, and decrement major count
	 */
	TACTL &= ~TAIFG;
	if (--left == 0)
	  break;
      }
    }
  }

  event void Msp430ClockInit.setupDcoCalibrate() {
    call Msp430ClockInit.defaultSetupDcoCalibrate();
  }
  
  /*
   * using SMCLK = DCO = 8MHz.  /8 gives us 1us ticks.
   *
   * Assumes interrupts off.
   */
  event void Msp430ClockInit.initTimerA() {

    /*
     * FIX ME.  Does this make it so low power mode doesn't
     * do its thing?  Also how often do we want to resyncronize
     * the clock (DCO).
     */

    // TACTL
    // .TASSEL = 2;	source SMCLK = DCO
    // .ID = 3;		input divisor of 8 (DCO/8)
    // .MC = 2;		continuously running
    // .TACLR = 0;
    // .TAIE = 1;	enable timer A interrupts
    TAR = 0;
    TACTL = TASSEL_2 | ID_3 | MC_2 | TAIE;
  }

  event void Msp430ClockInit.initTimerB() {
    call Msp430ClockInit.defaultInitTimerB();
  }

  event void Msp430ClockInit.initClocks() {
    // BCSCTL1
    // .XT2OFF = 1;	external osc off
    // .XTS = 0;	low frequency mode for LXFT1
    // .DIVA = 0;	ACLK/1
    // .RSEL,		do not modify
    BCSCTL1 = XT2OFF | (BCSCTL1 & RSEL_MASK);

    // BCSCTL2
    // .SELM = 0;	MCLK <- DCO/1
    // .DIVM = 0;	MCLK divisor 1
    // .SELS = 0;	SMCLK <- DCO/1
    // .DIVS = 0;	SMCLK divisor 1
    // .DCOR = 0;	internal resistor
    BCSCTL2 = 0;

    // BCSCTL3: use default, on reset set to 4, 6pF.

    // IE1.OFIE = 0; no interrupt for oscillator fault
    CLR_FLAG( IE1, OFIE );
  }

  command error_t Init.init() __attribute__ ((noinline)) {
    TOSH_MM_INITIAL_PIN_STATE();

    /*
     * It takes a long time for the 32KHz Xtal to come up.
     * Go look to see when we start getting 32KHz ticks.
     * The routine waits for a second to give it time to
     * start up.
     */
    wait_for_32K();
    call ClockInit.init();
    call LedsInit.init();
    return SUCCESS;
  }

  async command void Led2.set() { };
  async command void Led2.clr() { };
  async command void Led2.toggle() { };
  async command bool Led2.get() { return 0; };
  async command void Led2.makeInput() { };
  async command bool Led2.isInput() { return FALSE; };
  async command void Led2.makeOutput() { };
  async command bool Led2.isOutput() { return FALSE; };  
  
  default command error_t LedsInit.init() { return SUCCESS; }
}
