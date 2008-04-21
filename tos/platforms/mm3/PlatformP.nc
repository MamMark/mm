#include "hardware.h"

#define STUFF_SIZE 256

noinit struct {
  uint8_t dcoctl;
  uint8_t bcsctl1;
  uint8_t bcsctl2;
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
  stuff[nxt].dcoctl = DCOCTL;
  stuff[nxt].bcsctl1 = BCSCTL1;
  stuff[nxt].bcsctl2 = BCSCTL2;
  nxt++;
}
      

module PlatformP{
  provides {
    interface Init;
    interface GeneralIO as Led2;
  }
  uses {
    interface Init as Msp430ClockInit;
    interface Init as LedsInit;
  }
}

implementation {

#define PWR_UP_CYCLES_32KHZ 128

  void wait_for_32K() __attribute__ ((noinline)) {
    uint16_t t1, t2;

    TACTL = TACLR;
    TAIV = 0;
    TBCTL = TBCLR;
    TBIV = 0;
    TACTL = TASSEL1 | MC1; // source SMCLK, continuous mode, everything else 0
    TBCTL = TBSSEL0 | MC1;
    BCSCTL1 = XT2OFF | RSEL2;
    BCSCTL2 = 0;
    TBCCTL0 = 0;

    while (1) {
      t1 = TBR;
      t2 = TBR;
      if (t1 == t2 && t2 >= PWR_UP_CYCLES_32KHZ)
	break;
    }
  }

  command error_t Init.init() __attribute__ ((noinline)) {
    TOSH_MM3_INITIAL_PIN_STATE();

    /*
     * It takes a long time for the 32KHz Xtal to come up.
     * Go look to see when we start getting 32KHz ticks.
     * Wait for 10.
     */
    wait_for_32K();

    set_stuff();
    call Msp430ClockInit.init();
    set_stuff();

    /*
     * I know there is some way to mess with changing the default
     * commands in Msp430ClockInit but not sure how to do it.
     * So for now just do it by forcing it.
     *
     * Originally SMCLK was set as DCO/4 and Timer A was run
     * as SMCLK/1.  The problem is the SPI is clocked off
     * SMCLK and its minimum divisor is /2 which gives us DCO/8.
     * We want to run the SPI as fast as possible.  SPI0 is the
     * ADC and SPI1 is the radio and SD card.  Both need to run
     * as fast as possible.
     *
     * So after initilizing using the original code we wack
     * BCSCTL2 to make SMCLK be DCO and TACTL to change its
     * divisor to /4 to maintain 1uS ticks.
     *
     * This effects the serial usart (uart1) used for direct
     * connect.  So the UBR register values must be modified for
     * that as well.  See mm3SerialP.nc.
     */

    // BCSCTL2
    // .SELM = 0; select DCOCLK as source for MCLK
    // .DIVM = 0; set the divisor of MCLK to 1
    // .SELS = 0; select DCOCLK as source for SCLK
    // .DIVS = 0; set the divisor of SCLK to 1
    //            was formerly 2 (/4)
    // .DCOR = 0; select internal resistor for DCO
    BCSCTL2 = 0;

    // TACTL
    // .TACLGRP = 0; each TACL group latched independently
    // .CNTL = 0; 16-bit counter
    // .TASSEL = 2; source SMCLK = DCO
    // .ID = 2; input divisor of 4 (DCO/4)
    // .MC = 2; continuously running
    // .TACLR = 0; reset timer A
    // .TAIE = 1; enable timer A interrupts

    /*
     * FIX ME.  Does this make it so low power mode doesn't
     * do its thing?  Also how often do we want to resyncronize
     * the clock (DCO).
     */
    TACTL = TASSEL1 | ID1 | MC1 | TAIE;
    TAR = 0;

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
