/**
 * Copyright 2008, 2010 (c) Eric Decker
 * All rights reserved.
 *
 * @author Eric B. Decker
 */

#ifndef _H_MM3_PORT_REGS_H_
#define _H_MM3_PORT_REGS_H_

  static volatile struct {
    uint8_t dmux            : 2;
    uint8_t mag_deguass1    : 1;
    uint8_t gps_rx_out      : 1;
    uint8_t mag_deguass2    : 1;
    uint8_t press_res_off   : 1;
    uint8_t salinity_off    : 1;
    uint8_t press_off       : 1;
  } mmP1out asm("0x0021");

  static volatile struct {
    uint8_t u8_inhibit		: 1;
    uint8_t accel_wake		: 1;
    uint8_t salinity_pol_sw	: 1;
    uint8_t u12_inhibit		: 1;
    uint8_t smux_low2		: 2;
    uint8_t adc_cnv		: 1;
    uint8_t			: 1;
  } mmP2out asm("0x0029");

#define ADC_CNV mmP2out.adc_cnv

  static volatile struct {
    uint8_t			: 1;
    uint8_t smux_a2		: 1;
    uint8_t adcx_sdo		: 1;	/* input */
    uint8_t adcx_clk		: 1;
    uint8_t tmp_on		: 1;
    uint8_t adcx_sdi		: 1;
    uint8_t utxd1		: 1;
    uint8_t urxd1_o		: 1;
  } mmP3out asm("0x0019");

#ifdef not_def
#define ADC_SDO mmP3out.adc_sdo
#define ADC_CLK mmP3out.adc_clk
#define ADC_SDI mmP3out.adc_sdi
#endif

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
    uint8_t sd_sdi		: 1;
    uint8_t sd_sdo		: 1;
    uint8_t sd_clk		: 1;
    uint8_t sd_csn		: 1;	/* chip select low true (deselect) */
    uint8_t rf_beep_off		: 1;
    uint8_t ser_sel		: 2;
  } mmP5out asm("0x0031");

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
 * SD_PINS_OUT_0 will set SPI1/SD data pins to output 0.  (no longer
 * connected to the SPI module.  The values of these pins is assumed to be 0.
 * Direction of the pins is assumed to be output.  So the only thing that
 * needs to happen is changing from ModuleFunc to PortFunc.
 */

#define SD_PINS_OUT_0 do { P5SEL &= ~0x0e; } while (0)

/*
 * SD_PINS_SPI will connect the 3 data lines on the SD to the SPI.
 *
 * 5.4 CSN left alone (already assumed to be properly set)
 * 5.1-3 SDI, SDO, CLK set to SPI Module.
 */
#define SD_PINS_SPI   do { P5SEL |= 0x0e; } while (0)

  static volatile struct {
    uint8_t led_r		: 1;
    uint8_t led_y		: 1;
    uint8_t led_g		: 1;
    uint8_t tell		: 1;
    uint8_t speed_off		: 1;
    uint8_t mag_xy_off		: 1;
    uint8_t			: 1;
    uint8_t mag_z_off		: 1;
  } mmP6out asm("0x0035");
  
#define TELL mmP6out.tell

#endif
