/*
 * Copyright 2010 (c) Eric B. Decker
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
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * @author Eric B. Decker
 */

#ifndef _H_MM4_PORT_REGS_H
#define _H_MM4_PORT_REGS_H

#ifndef PACKED
#define PACKED __attribute__((__packed__))
#endif

  static volatile struct {
    uint8_t dmux            : 2;
    uint8_t mag_deguass1    : 1;
    uint8_t tell	    : 1;
    uint8_t mag_deguass2    : 1;
    uint8_t press_res_off   : 1;
    uint8_t salinity_off    : 1;
    uint8_t press_off       : 1;
  } PACKED mmP1out asm("0x0021");

#define TELL mmP1out.tell

  static volatile struct {
    uint8_t u8_inhibit		: 1;
    uint8_t accel_wake		: 1;
    uint8_t salinity_pol_sw	: 1;
    uint8_t u12_inhibit		: 1;
    uint8_t smux_low2		: 2;
    uint8_t adc_cnv		: 1;
    uint8_t			: 1;
  } PACKED mmP2out asm("0x0029");

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
  } PACKED mmP3out asm("0x0019");

#define TMP_ON mmP3out.tmp_on

norace static volatile struct {
    uint8_t gmux		: 2;
    uint8_t vdiff_off		: 1;
    uint8_t vref_off		: 1;
    uint8_t solar_chg_on	: 1;
    uint8_t extchg_battchk	: 1;
    uint8_t gps_off		: 1;
    uint8_t smux_a2		: 1;
  } PACKED mmP4out asm("0x001d");

#define SMUX_A2 mmP4out.smux_a2

norace static volatile struct {
    uint8_t sd_pwr_off		: 1;
    uint8_t adcx_sdi		: 1;	/* not used, reserved */
    uint8_t adcx_sdo		: 1;	/* input */
    uint8_t adcx_clk		: 1;
    uint8_t sd_csn		: 1;	/* chip select low true (deselect) */
    uint8_t rf_beep_off		: 1;
    uint8_t ser_sel		: 2;
  } PACKED mmP5out asm("0x0031");

#define SER_SEL mmP5out.ser_sel

  enum {
    SER_SEL_DOCK   =	0,
    SER_SEL_GPS    =	1,
    SER_SEL_UNUSED =	2,
    SER_SEL_NONE   =	3,
  };

#define SD_CSN      mmP5out.sd_csn
#define SD_PWR_ON  (mmP5out.sd_pwr_off = 0)
#define SD_PWR_OFF (mmP5out.sd_pwr_off = 1)

/*
 * SD_PINS_INPUT will set SPI0/SD data pins to inputs.  (no longer
 * connected to the SPI module.  The values of these pins doesn't
 * matter but are assumed to be 0.  We are setting to inputs so who cars.
 * Direction of the pins is assumed to be input.  So the only thing that
 * needs to happen is changing from ModuleFunc to PortFunc.
 *
 * We also set SD_CSN to an input to avoid powering the chip.
 *
 * Similarily for the GPS uart pins.  Default setup is done in
 * platform init and sets direction to input.  This isn't changed.
 */

#define SD_PINS_INPUT  do { P3SEL &= ~0x0e;   P5DIR &= ~0x10; } while (0)
#define GPS_PINS_INPUT do { P3SEL &= ~0x30; } while (0)


/*
 * SD_PINS_SPI will connect the 3 data lines on the SD to the SPI.
 * And switches the sd_csn (5.4) from input to output,  the value should be
 * a 1 which deselects the sd and tri-states.
 *
 * 3.1-3 SDI, SDO, CLK set to SPI Module, SD_CSN switched to output
 * (assumed 1, which is CSN, CS deasserted).
 *
 * Similarily for the GPS uart pins.
 */
#define SD_PINS_SPI   do { P3SEL |= 0x0e;   P5DIR |= 0x10; } while (0)
#define GPS_PINS_UART do { P3SEL |= 0x30; } while (0)


  static volatile struct {
    uint8_t led_r		: 1;
    uint8_t led_y		: 1;
    uint8_t led_g		: 1;
    uint8_t			: 1;
    uint8_t speed_off		: 1;
    uint8_t mag_xy_off		: 1;
    uint8_t adcx_sdi		: 1;
    uint8_t mag_z_off		: 1;
  } PACKED mmP6out asm("0x0035");
  
#endif
