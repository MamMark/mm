#include "hardware.h"

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
  command error_t Init.init() {
    TOSH_MM3_INITIAL_PIN_STATE();
    call Msp430ClockInit.init();

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

    TAR = 0;

    // TACTL
    // .TACLGRP = 0; each TACL group latched independently
    // .CNTL = 0; 16-bit counter
    // .TASSEL = 2; source SMCLK = DCO
    // .ID = 2; input divisor of 4 (DCO/4)
    // .MC = 0; initially disabled
    // .TACLR = 0; reset timer A
    // .TAIE = 1; enable timer A interrupts
    TACTL = TASSEL1 | ID1 | TAIE;

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
