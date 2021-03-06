/**
 *
 * Copyright 2008-2010 (c) Eric B. Decker
 * All rights reserved.
 *
 * @author Eric B. Decker
 */

#ifndef _H_HARDWARE_h
#define _H_HARDWARE_h

#include "msp430hardware.h"
#include "mm3PortRegs.h"

/*
 * Basic clock system has 3 or 4 RSEL bits depending on whether
 * BC2 (Basic clock 2).  We use RSEL3 to determine how wide the
 * field is.
 *
 * This only works for MSP430 (1611) or MSP430X (2618).  The 5438
 * parts use the UCS and are very different.
 */
#ifdef RSEL3
#define RSEL_MASK (RSEL0 | RSEL1 | RSEL2 | RSEL3)
#define RSEL_MAX RSEL3
#else
#define RSEL_MASK (RSEL0 | RSEL1 | RSEL2)
#define RSEL_MAX RSEL2
#endif

/*
 * Port definitions:
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
 *      gps is wired to a mux and then to uart1.  And power up/down
 *	cc2420 (spi1), sd (spi1), gps, and serial direct connect (uart1) on same usart.
 *
 * port 1.0	0pO	d_mux_a0		port 4.0	0pO	gain_mux_a0
 *       .1	0pO	d_mux_a1		      .1	0pO	gain_mux_a1
 *       .2	0pO	mag_degauss_1		      .2	1pO	vdiff_off
 *       .3     0pO		  		      .3	1pO	vref_off
 *       .4	0pO	mag_deguass_2		      .4	0pO	solar_chg_on
 *       .5	1pO	press_res_off		      .5	0pO	extchg_battchk
 *       .6	1pO	salinity_off		      .6	1pO	gps_off
 *       .7	1pO	press_off		      .7	1pO	led_g (rf232_pwr off)
 *
 * port 2.0	1pO	U8_inhibit		port 5.0	1pO	sd_pwr_off (1 = off)
 *       .1	0pO	accel_wake		      .1	0sO	sd_di (simo1, spi1)  (0pO, sd off)
 *       .2	0pO	salinity_polarity	      .2	0sI	sd_do (somi1, spi1)  (0pO, sd off)
 *       .3	1pO	u12_inhibit		      .3	0sO	sd_clk (uclk1, spi1) (0pO, sd off)
 *       .4	0pO	s_mux_a0		      .4	0pO	sd_csn (cs low true) (0pO, sd off)
 *       .5	0pO	s_mux_a1		      .5	0pO	rf_beeper_off
 *       .6	0pO	adc_cnv			      .6	1pO	ser_sel_a0
 *       .7	0pI	adc_da0			      .7	1pO	ser_sel_a1
 *
 * port 3.0	0pO				port 6.0	0pI	led_r
 *       .1	0pO	s_mux_a2		      .1	0pI	led_y
 *       .2	0sI	adc_somi, adc_sdo (spi0)      .2	0pI	led_g
 *       .3	0sO	adc_clk, (uclk0, spi0)	      .3	0pO	telltale
 *       .4	0pO	tmp_on			      .4	1pO	speed_off
 *       .5	1pO	adc_sdi (not part of spi)     .5	1pO	mag_xy_off
 *			  (mode control in, adc)
 *       .6	1pO	ser_txd (uart1)		      .6	1pO
 *       .7	0pI	ser_rxd (uart1)		      .7	1pO	mag_z_off
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
 * USART Pins
 *
 * usart 0 is dedicated to the ADC in SPI mode.  3.2-3, 5-6.
 * 2.7 is an input coming from the ADC that indicates the conversion
 * is complete.
 *
 * usart 1 is shared between the sd (spi), radio (spi), gps, and direct connect
 * (gps and direct connect use the uart).  The radio is mutually exclusive with
 * direct connect.
 *
 * uart1 is used to communicate with the direct connect cradle or with the gps.
 * The gps also connects to p1.3 which allows an interrupt to be generated when
 * the gps starts to send data.  This pin can also be used in conjunction with
 * Timer A to implement a s/w uart.  Which port is connected is determined by
 * the settings on a h/w multiplexor.
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
 * rx in, tx out/1, adc_sdi high (sets mode), temp off, s_mux 0
 * ser_txd is set to 1 (mark).
 *
 * ADC_SDO and ADC_CLK are assigned to SPI0
 */
#define P3_BASE_DIR	0x7b
#define P3_BASE_VAL	0x60
#define P3_BASE_SEL	0x0c

/* gps off, no batt chk, no solar, vref/vdiff off, g_mux 0 */
#define P4_BASE_DIR	0xff
#define P4_BASE_VAL	0xcc

/*
 * ser_sel 3 (none), beeper off, sd bits 0pO, sd pwr off 1pO
 * (when powered off we dont want to power the chip via any of its other
 * pins).  So set any pins connected to the SD to output 0.
 */
#define P5_BASE_DIR	0xff
#define P5_BASE_VAL	0xe1

/* mag pwr off */
#define P6_BASE_DIR	0xf8
#define P6_BASE_VAL	0xf0


inline void uwait(uint16_t u) {
  uint16_t t0 = TAR;
  while((TAR - t0) <= u);
}


void TOSH_MM_INITIAL_PIN_STATE(void) {
  atomic {
    SVSCTL = 0;			/* for now, disable SVS */
    U0CTL = SWRST;		/* hold USART0 in reset */
    U1CTL = SWRST;		/* and  USART1 as well  */
    ME1 = 0;
    ME2 = 0;

    P1SEL = 0;			/* all ports port function */
    P1DIR = P1_BASE_DIR;
    P1OUT = P1_BASE_VAL;
    P1IES = 0;
    P1IFG = 0;

    P2SEL = 0;
    P2DIR = P2_BASE_DIR;
    P2OUT = P2_BASE_VAL;
    P2IES = 0;
    P2IFG = 0;

    P3SEL = P3_BASE_SEL;
    P3DIR = P3_BASE_DIR;
    P3OUT = P3_BASE_VAL;

    P4SEL = 0;
    P4DIR = P4_BASE_DIR;
    P4OUT = P4_BASE_VAL;

    P5SEL = 0;
    P5DIR = P5_BASE_DIR;
    P5OUT = P5_BASE_VAL;

    P6SEL = 0;
    P6DIR = P6_BASE_DIR;
    P6OUT = P6_BASE_VAL;
  }
}

#endif // _H_HARDWARE_H
