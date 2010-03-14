/**
 *
 * Copyright 2010 (c) Eric B. Decker
 * All rights reserved.
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

#define PWR_UP_SEC 16

  /*
   * We assume that the clock system after reset has been
   * set to some reasonable value.  ie ~1MHz.  We assume that
   * all the selects are 0, ie.  DIVA/1, XTS 0, XT2OFF, SELM 0,
   * DIVM/1, SELS 0, DIVS/1.  MCLK <- DCO, SMCLK <- DCO,
   * LFXT1S 32768, XCAP ~6pf
   *
   * We wait about a second for the 32KHz to stablize.
   */
  void wait_for_32K() __attribute__ ((noinline)) {
    uint16_t left, t1;

    left = PWR_UP_SEC;
    TACTL = TACLR;
    TAIV = 0;
    TBCTL = TBCLR;
    TBIV = 0;
    TACTL = TASSEL_2 | MC_2;	// SMCLK/1, continuous
    TBCTL = TBSSEL_1 | MC_2;	//  ACLK/1, continuous
    TBCCTL0 = 0;

    /*
     * wait for about a sec for the 32KHz to come up and
     * stabilize.  We are guessing that it is stable and
     * on frequency after about a second but this needs
     * to be verified.
     *
     * FIX ME.
     */
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
    nop();
    t1 = TBR;
  }

  /*
   * I know there is some way to mess with changing the default
   * commands in Msp430ClockInit but not sure how to do it.
   * So for now just do it by forcing it.
   *
   * The telosB mote originally set SMCLK as DCO/4 and TimerA
   * was run with SMCLK/1.   The problem is the SPI is clocked off
   * SMCLK and its minimum divisor is /2 which gives us DCO/8.
   * Given a DCO frequency of 4MHz this would result in clocking
   * the SD/SPI at 512KHz.
   *
   * We want to run the SPI as fast as possible.  SPI0 is the
   * ADC and SPI1 is the radio and SD card.  Both need to run
   * as fast as possible.
   *
   * For MM3:  After initilizing using the original code we
   * wack BCSCTL2 to make SMCLK be DCO and TACTL to change
   * its divisor to /4 to maintain 1uis ticks.
   *
   * This effects the serial usart (uart1) used for direct
   * connect.  So the UBR register values must be modified for
   * that as well.  See mm3SerialP.nc.
   *
   * For MM4:  We clock the DCO for 8MHz (currently 8,000,000,
   * but eventually will be 8MiHz).   We run SMCLK and the SPI/SD
   * at 8MiHz and use /8 for TimerA.
   */

  event void Msp430ClockInit.setupDcoCalibrate() {
    call Msp430ClockInit.defaultSetupDcoCalibrate();
  }
  
  /*
   * set for DCO of 8MHz.  /8 gives us 1uis ticks.
   */
  event void Msp430ClockInit.initTimerA() {
    // TACTL
    // .TASSEL = 2; source SMCLK = DCO
    // .ID = 3; input divisor of 8 (DCO/8)
    // .MC = 2; continuously running
    // .TACLR = 0; reset timer A
    // .TAIE = 1; enable timer A interrupts

    /*
     * FIX ME.  Does this make it so low power mode doesn't
     * do its thing?  Also how often do we want to resyncronize
     * the clock (DCO).
     */
    TAR = 0;
    TACTL = TASSEL_2 | ID_3 | MC_2 | TAIE;
  }

  event void Msp430ClockInit.initTimerB() {
    call Msp430ClockInit.defaultInitTimerB();
  }

  event void Msp430ClockInit.initClocks() {
    BCSCTL1 = CALBC1_8MHZ;                    // Set DCO to 8MHz
    DCOCTL  = CALDCO_8MHZ;

    // BCSCTL1
    // .XT2OFF = 1; disable the external oscillator for SCLK and MCLK
    // .XTS = 0; set low frequency mode for LXFT1
    // .DIVA = 0; set the divisor on ACLK to 1
    // .RSEL, do not modify
    BCSCTL1 = XT2OFF | (BCSCTL1 & (RSEL2|RSEL1|RSEL0));

    // BCSCTL2
    // .SELM = 0; select DCOCLK as source for MCLK
    // .DIVM = 0; set the divisor of MCLK to 1
    // .SELS = 0; select DCOCLK as source for SCLK
    // .DIVS = 0; set the divisor of SCLK to 1
    //            was formerly 2 (/4)
    // .DCOR = 0; select internal resistor for DCO
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
     * Wait for 10.
     */
    wait_for_32K();

//    set_stuff();
    call ClockInit.init();
//    set_stuff();
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
