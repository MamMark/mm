#ifndef _H_hardware_h
#define _H_hardware_h

/*
 * This is the do nothing layer for use on the TelosB.  It makes the
 * h/w interface layer do nothing.
 */

/*
 * Port definitions:
 *
 * what do these damn codes mean?  (<dir><usage><default val>: Is0 <input><spi><0, zero>)
 * another nomenclature used is <value><function><direction>, 0pO (0 (zero), port, Output),
 *    xpI (don't care, port, Input).
 *
 * Need:
 *	red, green, yellow leds
 *	cc2420: csn, vref, reset, fifop, sfd, gio0, fifo, gio1, cca
 *	    cc: fifop, fifo, sfd, vren, rstn (these aren't assigned, where to put them)
 *	  (cc2420 power down?)
 *
 *	put adc and cc2420 on same bus?  what about sd?
 *
 *	gps pwr?
 *	serial select?   (one bit for switch between comm and gps)
 *
 * port 1.0	O	d_mux_a0		port 4.0	O	gain_mux_a0
 *       .1	O	d_mux_a1		      .1	O	gain_mux_a1
 *       .2	O	mag_degauss_1		      .2	O	vdiff_pwr
 *       .3	O	speed_pwr		      .3	O	vref_pwr
 *       .4	O	mag_deguass_2		      .4	O	solar_chg
 *       .5	O	press_res_pwr		      .5	O	extchg_battchk
 *       .6	O	salinity_pwr		      .6	O	gps_pwr	off
 *       .7	O	press_pwr		      .7	O	cc2420_vref
 *
 * port 2.0	O	U8_inhibit		port 5.0	O	sd_pwr
 *       .1	O	accel_wake		      .1	Os1	sd_di (simo1, spi1)
 *       .2	O	salinity_polarity	      .2	Is1	sd_do (somi1, spi1)
 *       .3	O	u12_inhibit		      .3	Os1	sd_clk (uclk1, spi1)
 *       .4	O	s_mux_a0		      .4	O	sd_csn (cs low true)
 *       .5	O	s_mux_a1		      .5	O	rf_beeper_pwr
 *       .6	O	adc_cnv			      .6	O	ser_sel_a0  (gps_in)
 *       .7	I	adc_somi_ta0 (ta0)	      .7	O	ser_sel_a1  (cc2420_reset)
 *
 * port 3.0	O	cc2420_csn		port 6.0	O	cc2420_fifop
 *       .1	O	s_mux_a2		      .1	O	cc2420_sfd
 *       .2	Is0	adc_somi (spi0)		      .2	I	cc2420_fifo
 *       .3	Os0	adc_clk (uclk0, spi0)	      .3	O	telltale (cc2420_cca)
 *       .4	O	tmp_pwr	on		      .4	O	led_g
 *       .5	O	adc_mosi (not part of spi)    .5	O	mag_xy_pwr
 *       .6	Ou1	ser_txd (uart1)		      .6	O	led_y
 *       .7	Iu0	ser_rxd (uart1)		      .7	O	mag_z_pwr
 */

#include "msp430hardware.h"

/*
 * Use the led pins as defined on the telosb
 */
TOSH_ASSIGN_PIN(RED_LED,    5, 4);
TOSH_ASSIGN_PIN(GREEN_LED,  5, 5);
TOSH_ASSIGN_PIN(YELLOW_LED, 5, 6);

#ifdef notdef
/* telosb mote pins for messing around */
TOSH_ASSIGN_PIN(DMUX_A0, 5, 0);
TOSH_ASSIGN_PIN(DMUX_A1, 5, 1);
TOSH_ASSIGN_PIN(U8_INHIBIT, 5, 2);
TOSH_ASSIGN_PIN(U12_INHIBIT, 5, 3);

TOSH_ASSIGN_PIN(SMUX_A0, 5, 4);
TOSH_ASSIGN_PIN(SMUX_A1, 5, 5);
TOSH_ASSIGN_PIN(SMUX_A2, 5, 6);

TOSH_ASSIGN_PIN(GMUX_A0, 6, 0);
TOSH_ASSIGN_PIN(GMUX_A1, 6, 1);
#endif

#ifdef notdef
TOSH_ASSIGN_PIN(DMUX_A0, 1, 0);
TOSH_ASSIGN_PIN(DMUX_A1, 1, 1);
TOSH_ASSIGN_PIN(U8_INHIBIT, 2, 0);
TOSH_ASSIGN_PIN(U12_INHIBIT, 2, 3);

TOSH_ASSIGN_PIN(SMUX_A0, 2, 4);
TOSH_ASSIGN_PIN(SMUX_A1, 2, 5);
TOSH_ASSIGN_PIN(SMUX_A2, 3, 1);

TOSH_ASSIGN_PIN(GMUX_A0, 4, 0);
TOSH_ASSIGN_PIN(GMUX_A1, 4, 1);
#endif

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

/*
 * USART Pins
 *
 * The ADC (external) is connected to USART0
 * We also include other ADC control signals
 */

#ifdef notdef
TOSH_ASSIGN_PIN(ADC_SOMI, 3, 2);
TOSH_ASSIGN_PIN(ADC_CLK,  3, 3);
TOSH_ASSIGN_PIN(ADC_MOSI, 3, 5);
TOSH_ASSIGN_PIN(ADC_CNV,  2, 6);
TOSH_ASSIGN_PIN(ADC_SOMI_TA0, 2, 7);

/*
 * USART1, serial uart
 */
TOSH_ASSIGN_PIN(UTXD1, 3, 6);
TOSH_ASSIGN_PIN(URXD1, 3, 7);

/*
 * USART1, SPI mode used for the SD
 */
TOSH_ASSIGN_PIN(SD_PWR, 5, 0);
TOSH_ASSIGN_PIN(SD_DI,  5, 1);
TOSH_ASSIGN_PIN(SD_DO,  5, 2);
TOSH_ASSIGN_PIN(SD_CLK, 5, 3);
TOSH_ASSIGN_PIN(SD_CSN, 5, 4);
#endif

/*
 * Power Control
 */

#define VREF_TURN_ON   TRUE
#define VREF_TURN_OFF  FALSE
#define VDIFF_TURN_ON  TRUE
#define VDIFF_TURN_OFF FALSE

#ifdef notdef
TOSH_ASSIGN_PIN(VREF_PWR, 4, 3);
TOSH_ASSIGN_PIN(VDIFF_PWR, 4, 2);

TOSH_ASSIGN_PIN(SPEED_PWR, 1, 3);
TOSH_ASSIGN_PIN(PRESS_RES_PWR, 1, 5);
TOSH_ASSIGN_PIN(PRESS_PWR, 1, 7);
TOSH_ASSIGN_PIN(ACCEL_WAKE, 2, 1);

TOSH_ASSIGN_PIN(SALINITY_PWR, 1, 6);
TOSH_ASSIGN_PIN(SALINITY_POLARITY, 2, 2);

TOSH_ASSIGN_PIN(TEMP_PWR, 3, 4);
TOSH_ASSIGN_PIN(RF_BEEPER_PWR, 5, 5);
TOSH_ASSIGN_PIN(MAG_XY_PWR, 6, 6);
TOSH_ASSIGN_PIN(MAG_Z_PWR, 6, 7);
#endif


/*
 * Misc other control signals
 */

#ifdef notdef
TOSH_ASSIGN_PIN(MAG_DEGAUSS_1, 1, 2);
TOSH_ASSIGN_PIN(MAG_DEGAUSS_2, 1, 4);
TOSH_ASSIGN_PIN(SOLAR_CHG, 4, 4);
TOSH_ASSIGN_PIN(EXTCHG_BATTCHK, 4, 5);
TOSH_ASSIGN_PIN(SER_SEL_A0, 5, 6);
TOSH_ASSIGN_PIN(SER_SEL_A1, 5, 7);
#endif


// need to undef atomic inside header files or nesC ignores the directive
#undef atomic

/* init_ports_pwr - Initilize Ports and Pwr system
 *
 * Set initial state of ports to something reasonable.  Although we
 * assume that we have just been reset, we explicitly make sure
 * that the system is in a reasonable state.  That way we can call
 * init_ports_pwr whenever we want and it will do the right thing.
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
 * Set the ports to reflect the i/o directions detailed above.
 * SPI0 enabled, UART1 disabled, SPI1 disabled.
 *
 * P3.(2,3)   -> SPI0  (USART0), disabled
 * P3.(6,7)   -> UART1 (USART1), disabled
 * P5.(1,2,3) -> SPI1  (USART1), disabled
 *
 * When a function is disabled, its corresponding pins are
 * switched back to port function, the module disabled, and it's
 * pins set to output 0's.  This avoids powering the chip when
 * power is off through the input clamps.  (Need to check whether
 * this is valid for chip outputs as well, currently the code
 * sets these pins the same as chip inputs).
 *
 * init_ports also makes sure that all modules are powered off.
 * Any pins connected to power fets are set to power down the
 * circuit.  Any pins connected to i/o pins on a powered down
 * chip will be set to output a 0.
 *
 * Direction: 0 for input, 1 for output.
 * Selects:   0 for port function, 1 for module function.
 */


/* all pwr bits high (off), d_mux = 0 */
#define P1_BASE_DIR	0xff
#define P1_BASE_VAL	0xec

/* cnv low, s_mux = 0, accel sleeping, u8/12 inhibit */
#define P2_BASE_DIR	0x7f
#define P2_BASE_VAL	0x09

/* rx in, tx out/0, adc_sdi high, temp off, s_mux 0 */
#define P3_BASE_DIR	0x7b
//#define P3_BASE_VAL	0x60
/* while playing with the gps make sure that 3.6 TxD is a 0
   for when the gps is powered off, there are problems with
   the serial mux */
#define P3_BASE_VAL	0x40

/* gps/rf232 off, no batt chk, no solar, vref/vdiff off, g_mux 0 */
#define P4_BASE_DIR	0xff
#define P4_BASE_VAL	0xcc

/* ser_sel 3 (nothing), beeper off, sd bits xpI, sd pwr off 1pO
 * us1_init->sd_init takes care of putting signal states into
 * correct states.
 */
#define P5_BASE_DIR	0xe1
#define P5_BASE_VAL	0xf1

/* mag pwr off, rf232 bits outputs/0 */
#define P6_BASE_DIR	0xff
#define P6_BASE_VAL	0xf0


#ifdef notdef
void TOSH_MM3_INITIAL_PIN_STATE(void) {
  atomic {
    SVSCTL = 0;			/* for now, disable SVS */
    U0CTL = SWRST;		/* hold USART0 in reset */
    U1CTL = SWRST;		/* and  USART1 as well  */
    ME1 = 0;
    ME2 = 0;

    P1SEL = 0;			/* all ports port function */
    P1DIR = P1_BASE_DIR;
    P1OUT = P1_BASE_VAL;

    P2SEL = 0;
    P2DIR = P2_BASE_DIR;
    P2OUT = P2_BASE_VAL;

    P3SEL = 0;
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
#endif

void TOSH_MM3_B_PIN_STATE(void) {
  atomic {
    SVSCTL = 0;			/* for now, disable SVS */
    U0CTL = SWRST;		/* hold USART0 in reset */
    U1CTL = SWRST;		/* and  USART1 as well  */
    ME1 = 0;
    ME2 = 0;

    TOSH_MAKE_RED_LED_OUTPUT();
    TOSH_MAKE_GREEN_LED_OUTPUT();
    TOSH_MAKE_YELLOW_LED_OUTPUT();

#ifdef notdef
    TOSH_MAKE_DMUX_A0_OUTPUT();
    TOSH_MAKE_DMUX_A1_OUTPUT();
    TOSH_MAKE_U8_INHIBIT_OUTPUT();
    TOSH_MAKE_U12_INHIBIT_OUTPUT();

    TOSH_MAKE_SMUX_A0_OUTPUT();
    TOSH_MAKE_SMUX_A1_OUTPUT();
    TOSH_MAKE_SMUX_A2_OUTPUT();

    TOSH_MAKE_GMUX_A0_OUTPUT();
    TOSH_MAKE_GMUX_A1_OUTPUT();
#endif
  }
}

#endif // _H_hardware_h
