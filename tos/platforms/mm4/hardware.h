/**
 *
 * Copyright 2010 (c) Eric B. Decker
 * All rights reserved.
 *
 * @author Eric B. Decker
 */

#ifndef _H_HARDWARE_h
#define _H_HARDWARE_h

#include "msp430hardware.h"
#include "mm4PortRegs.h"

/*
 * Port definitions:
 *
 * changes from mm3:
 *
 * . put gps on usciA0, uart0)
 *   - move    p3.4 -> p3.0 tmp_on
 *   - adc_sdi p3.5 -> p6.6
 *   - gps serial on p3.4, p3.5 (dedicated, usciA0, uart)
 *
 * . dock on p3.6, p3.7 (dedicated, usciA1, uart)
 *
 * . swap spi ports: adc and sd (usciB0 <-> usciB1).  need sd
 *   on dma port.
 *   - adc to usciB1, 3.2 -> 5.2, 3.3 -> 5.3
 *   - s_mux_a1, 3.1 -> 5.1
 *   - sd to usciB0 for dma. 5.1 -> 3.1, 5.2 -> 3.2, 5.3 -> 3.3
 *
 * Various codes for port settings: (<dir><usage><default val>: Is0 <input><spi><0, zero>)
 * another nomenclature used is <value><function><direction>, 0pO (0 (zero), port, Output),
 *    xpI (don't care, port, Input), mI (module input).
 *
 * Other functions wanted:
 *	red, green, yellow leds
 *	cc2420: csn, vref, reset, fifop, sfd, gio0, fifo, gio1, cca
 *	    cc: fifop, fifo, sfd, vren, rstn (these aren't assigned, where to put them)
 *	  (cc2420 power down?)
 *
 *	sd (spi0, usciB0), gps (uart0, usciA0), and dock serial (uart1, usciA1).
 *      pins p3.1, 3.2, 3.3;   p3.5, 3.4            p3.6, 3.7
 *
 *      adc (spi1, usciB1): p5.3, 5.2
 *
 * port 1.0	0pO	d_mux_a0		port 4.0	0pO	gain_mux_a0
 *       .1	0pO	d_mux_a1		      .1	0pO	gain_mux_a1
 *       .2	0pO	mag_degauss_1		      .2	1pO	vdiff_off
 *       .3     0pO	telltale  		      .3	1pO	vref_off
 *       .4	0pO	mag_deguass_2		      .4	0pO	solar_chg_on
 *       .5	1pO	press_res_off		      .5	0pO	extchg_battchk
 *       .6	1pO	salinity_off		      .6	1pO	gps_off
 *       .7	1pO	press_off		      .7	0pI
 *
 * port 2.0	1pO	U8_inhibit		port 5.0	1pO	sd_pwr_off (1 = off)
 *       .1	0pO	accel_wake		      .1	0pO	s_mux_a2
 *       .2	0pO	salinity_polarity	      .2	0sI     adc_somi, adc_sdo (spi1, uB1)
 *       .3	1pO	u12_inhibit		      .3	0sO     adc_clk, (uclk0, spi1, uB1)
 *       .4	0pO	s_mux_a0		      .4	1pO	sd_csn (cs low true) (1pI, sd off)
 *       .5	0pO	s_mux_a1		      .5	1pO	rf_beeper_off
 *       .6	0pO	adc_cnv			      .6	1pO	ser_sel_a0
 *       .7	0pI	adc_da0			      .7	1pO	ser_sel_a1
 *
 * port 3.0	0pO	tmp_on			port 6.0	0pI	led_r
 *       .1	0sI	sd_di  (0pI, sd off)	      .1	0pI	led_y
 *       .2	0sI	sd_do  (0pI, sd off)	      .2	0pI	led_g
 *       .3	0sI	sd_clk (0pI, sd off)	      .3	0pI
 *       .4	1pI	gps_txd			      .4	1pO	speed_off
 *       .5	0pI	gps_rxd			      .5	1pO	mag_xy_off
 *       .6	1uI	dock_txd (uart1)	      .6	1pO	adc_sdi (not part of spi)
 *									  (mode control in, adc)
 *       .7	0uI	dock_rxd (uart1)	      .7	1pO	mag_z_off
 *
 * Note: When we used 6.3 as tell we saw no pull down.   Do we need to
 * enable the resistors (fets).
 */

/*
 * MUX Control
 *
 * Dmux controls which differential sensor is connected to
 * the differential amps.  The inhibits are involved.
 * (Dmux is P1.0-1)
 *
 * Gmux controls the gain the differential amps use.
 * (Gmux is P4.0-1)
 *
 * Smux controls which single ended sensor is selected.
 * also can select the output of the differential system.
 * (Smux is P2.4-5 and P3.1)
 *
 *
 * USCI Usage/Mapping
 *
 * usciA0: UART0 -> gps
 * usciA1: UART1 -> dock
 * usciB0: SPI0  -> SD
 * usciB1: SPI1  -> ADC
 *
 * USCI A1 is dedicated to the dock serial.  When docked the serial
 * mux selects dock_serial.  When undocked it should select none so
 * the serial lines aren't energized.
 *
 * 
 * USCI B0 (spi) is dedicated to the ADC.  3.2-3, 6.6
 * adc_da0 (2.7) is an input coming from the ADC that indicates the conversion
 * is complete.
 */

// LEDs
TOSH_ASSIGN_PIN(RED_LED, 6, 0);
TOSH_ASSIGN_PIN(YELLOW_LED, 6, 1);
TOSH_ASSIGN_PIN(GREEN_LED, 6, 2);

TOSH_ASSIGN_PIN(TELLx, 6, 3);

#ifdef notdef
// CC2420 RADIO #defines
TOSH_ASSIGN_PIN(RADIO_CSN, 4, 2);
TOSH_ASSIGN_PIN(RADIO_VREF, 4, 5);
TOSH_ASSIGN_PIN(RADIO_RESET, 4, 6);
TOSH_ASSIGN_PIN(RADIO_FIFOP, 1, 0);
TOSH_ASSIGN_PIN(RADIO_SFD, 4, 1);
TOSH_ASSIGN_PIN(RADIO_GIO0, 1, 3);
TOSH_ASSIGN_PIN(RADIO_FIFO, 1, 3);
TOSH_ASSIGN_PIN(RADIO_GIO1, 1, 4);
TOSH_ASSIGN_PIN(RADIO_CCA, 1, 4);

TOSH_ASSIGN_PIN(CC_FIFOP, 1, 0);
TOSH_ASSIGN_PIN(CC_FIFO, 1, 3);
TOSH_ASSIGN_PIN(CC_SFD, 4, 1);
TOSH_ASSIGN_PIN(CC_VREN, 4, 5);
TOSH_ASSIGN_PIN(CC_RSTN, 4, 6);

#endif

// need to undef atomic inside header files or nesC ignores the directive
#undef atomic

/*
 * Notes on power for sensors and peripherals.
 *
 * Set initial state of ports to something reasonable.  Although we
 * assume that we have just been reset, we explicitly make sure
 * that the mcu pins are in a reasonable state.
 *
 * After Power-Up Clear, the following state exists on the digitial
 * ports.
 *
 * PxIN		ro	-
 * PxOUT	rw	unchanged
 * PxDIR	rw	reset to 0 (pin input)
 * PxIFG	rw	reset to 0 (no pending interrupts)
 * PxIES	rw	unchanged
 * PxIE		rw	reset to 0 (no port interrupts)
 * PxSEL	rw	reset to 0 (port function)
 *
 * SPI0 enabled, UART1 disabled, SPI1 disabled.
 *
 * P3.(2,3)   -> SPI0  (USART0), enabled
 * P3.(6,7)   -> UART1 (USART1), disabled
 * P5.(1,2,3) -> SPI1  (USART1), disabled
 *
 * When a function is disabled, its corresponding pins are
 * switched back to port function, the module disabled, the pin
 * is set to input, the pin's POUT is set to 0.  This avoids
 * powering the chip when power is off through the input clamps.
 * (Need to check whether this is valid for chip outputs as well,
 * currently the code sets these pins the same as chip inputs).
 *
 * init_ports also makes sure that all modules are powered off.
 * Any pins connected to power fets are set to power down the
 * circuit.  Any pins connected to i/o pins on a powered down
 * chip will be set to 0pI (set to 0, port func, dir input).
 *
 * The ADC is connected to SPI0 and is always on (it goes into
 * low power mode itself).  Pins connected to SPI0 are assigned
 * at power up.
 *
 * Direction: 0 for input, 1 for output.
 * Selects:   0 for port, 1 for module function.
 */


/*
 * d_mux = 0 (inhibits will be high, u8/u12_inhibit)
 * all pwr bits high (off), degauss = 0
 */
#define P1_BASE_DIR	0xff
#define P1_BASE_VAL	0xe0

/*
 * s_mux = 0, accel sleeping, u8/12 inhibit
 * adc_cnv=0pO, gps_rx input.
 */
#define P2_BASE_DIR	0x7f
#define P2_BASE_VAL	0x09

/*
 * tmp_on 0 (off), sd is off, pins set to input.
 * GPS is off so we don't want to power it via its
 * uart pins.  Set to 0 (both inputs)  Dock uart is assumed
 * off (ser_sel <- None), set to inputs.
 *
 * Initially, both the gps and dock ports are assigned to port
 * function.  This allows us to directly control the state of
 * the port so when disconnected the pins aren't energized.
 */
#define P3_BASE_DIR	0x01
#define P3_BASE_VAL	0x50

/* gps off, no batt chk, no solar, vref/vdiff off, g_mux 0 */
#define P4_BASE_DIR	0x7f
#define P4_BASE_VAL	0x4c

/*
 * sd off (1), s_mux 0, adc_somi/adc_clk assigned to spi.
 * ser_sel 3 (none), beeper off
 *
 * ADC_SDO and ADC_CLK are assigned to USCI B1 SPI.
 */
#define P5_BASE_DIR	0xeb
#define P5_BASE_VAL	0xf1
#define P5_BASE_SEL	0x0c

/* mag pwr off */
#define P6_BASE_DIR	0xf0
#define P6_BASE_VAL	0xf0


inline void uwait(uint16_t u) {
  uint16_t t0 = TAR;
  while((TAR - t0) <= u);
}


void TOSH_MM_INITIAL_PIN_STATE(void) {
  atomic {
    SVSCTL = 0;			/* for now, disable SVS */
    UCA0CTL1 = UCSWRST;		/* hold gps uart in reset */
    UCA1CTL1 = UCSWRST;		/* hold dock uart in reset */
    UCB0CTL1 = UCSWRST;		/* hold ADC spi in reset */
    UCB1CTL1 = UCSWRST;		/* hold SD spi in reset */

    /*
     * set value first, then direction, eventually module/port (sel)
     */
    P1OUT = P1_BASE_VAL;
    P1DIR = P1_BASE_DIR;
    P1REN = 0;
    P1SEL = 0;			/* all ports port function */
    P1IES = 0;
    P1IFG = 0;

    P2OUT = P2_BASE_VAL;
    P2DIR = P2_BASE_DIR;
    P2REN = 0;
    P2SEL = 0;
    P2IES = 0;
    P2IFG = 0;

    P3OUT = P3_BASE_VAL;
    P3DIR = P3_BASE_DIR;
    P3REN = 0;
    P3SEL = 0;

    P4OUT = P4_BASE_VAL;
    P4DIR = P4_BASE_DIR;
    P4REN = 0;
    P4SEL = 0;

    P5OUT = P5_BASE_VAL;
    P5DIR = P5_BASE_DIR;
    P5REN = 0;
    P5SEL = P5_BASE_SEL;

    P6OUT = P6_BASE_VAL;
    P6DIR = P6_BASE_DIR;
    P6REN = 0;
    P6SEL = 0;
  }
}

#endif // _H_HARDWARE_H
