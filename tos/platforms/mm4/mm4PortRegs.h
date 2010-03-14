/**
 * Copyright 2010 (c) Eric B. Decker
 * All rights reserved.
 *
 * @author Eric B. Decker
 */

#ifndef _H_MM4_PORT_REGS_H
#define _H_MM4_PORT_REGS_H

  static volatile struct {
    uint8_t dmux            : 2;
    uint8_t mag_deguass1    : 1;
    uint8_t tell	    : 1;
    uint8_t mag_deguass2    : 1;
    uint8_t press_res_off   : 1;
    uint8_t salinity_off    : 1;
    uint8_t press_off       : 1;
  } mmP1out asm("0x0021");

#define TELL mmP1out.tell

  static volatile struct {
    uint8_t u8_inhibit		: 1;
    uint8_t accel_wake		: 1;
    uint8_t salinity_pol_sw	: 1;
    uint8_t u12_inhibit		: 1;
    uint8_t smux_low2		: 2;
    uint8_t adc_cnv		: 1;
    uint8_t			: 1;
  } mmP2out asm("0x0029");

#define SMUX_LOW2 mmP2out.smux_low2
#define ADC_CNV mmP2out.adc_cnv

  static volatile struct {
    uint8_t tmp_on		: 1;
    uint8_t sd_sdi		: 1;
    uint8_t sd_sdo		: 1;
    uint8_t sd_clk		: 1;
    uint8_t gpsx_txd		: 1;
    uint8_t gpsx_rxd		: 1;
    uint8_t dockx_utxd1		: 1;
    uint8_t dockx_urxd1_o	: 1;
  } mmP3out asm("0x0019");

#define TMP_ON mmP3out.tmp_on

norace static volatile struct {
    uint8_t gmux		: 2;
    uint8_t vdiff_off		: 1;
    uint8_t vref_off		: 1;
    uint8_t solar_chg_on	: 1;
    uint8_t extchg_battchk	: 1;
    uint8_t gps_off		: 1;
    uint8_t rf232_off		: 1;
  } mmP4out asm("0x001d");

norace static volatile struct {
    uint8_t sd_pwr_off		: 1;
    uint8_t smux_a2		: 1;
    uint8_t adcx_sdo		: 1;	/* input */
    uint8_t adcx_clk		: 1;
    uint8_t sd_csn		: 1;	/* chip select low true (deselect) */
    uint8_t rf_beep_off		: 1;
    uint8_t ser_sel		: 2;
  } mmP5out asm("0x0031");

#ifdef not_def
#define ADC_SDO mmP5out.adcx_sdo
#define ADC_CLK mmP5out.adc_clk
#endif

#define SMUX_A2 mmP5out.smux_a2
#define SER_SEL mmP5out.ser_sel

  enum {
    SER_SEL_CRADLE =	0,
    SER_SEL_GPS    =	1,	/* temp so we can see it via the uart */
    SER_SEL_UNUSED  =	2,
    SER_SEL_NONE   =	3,
  };

#define SD_CSN      mmP5out.sd_csn
#define SD_PWR_ON  (mmP5out.sd_pwr_off = 0)
#define SD_PWR_OFF (mmP5out.sd_pwr_off = 1)

/*
 * SD_PINS_IN will set SPI0/SD data pins to inputs.  (no longer
 * connected to the SPI module.  The values of these pins doesn't
 * matter but are assumed to be 0.  We are setting to inputs so who cars.
 * Direction of the pins is assumed to be input.  So the only thing that
 * needs to happen is changing from ModuleFunc to PortFunc.
 *
 * We also set SD_CSN to an input to avoid powering the chip.
 *
 * Similarily for the GPS uart pins.
 */

#define SD_PINS_INPUT  do { P3SEL &= ~0x0e;   P5DIR &= ~0x10; } while (0)
#define GPS_PINS_INPUT do { P3SEL &= ~0x03; } while (0)


/*
 * SD_PINS_SPI will connect the 3 data lines on the SD to the SPI.
 * And switches the sd_csn (5.4) from input to output,  the value should be
 * a 1 which deselects the sd and tri-states.
 *
 * 3.1-3 SDI, SDO, CLK set to SPI Module.
 *
 * Similarily for the GPS uart pins.
 */
#define SD_PINS_SPI   do { P3SEL |= 0x0e;   P5DIR |= 0x10; } while (0)
#define GPS_PINS_UART do { P3SEL |= 0x03; } while (0)


  static volatile struct {
    uint8_t led_r		: 1;
    uint8_t led_y		: 1;
    uint8_t led_g		: 1;
    uint8_t			: 1;
    uint8_t speed_off		: 1;
    uint8_t mag_xy_off		: 1;
    uint8_t adcx_sdi		: 1;
    uint8_t mag_z_off		: 1;
  } mmP6out asm("0x0035");
  
#endif
