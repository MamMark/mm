/*
 * Copyright (c) 2014-2016 Eric B. Decker
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
 * @author Eric B. Decker <cire831@gmail.com>
 */

#ifndef _H_hardware_h
#define _H_hardware_h

#include "msp430hardware.h"
#include "mmPortRegs.h"

/*
 * We are using the I2C single master driver.  Use the default configuration
 * so use UCMST instead of UCMM.
 *
 * 8MHz/80 -> 100KHz
 * 8MHz/20 -> 400KHz
 */
#define MSP430_I2C_MASTER_MODE UCMST
#define MSP430_I2C_DIVISOR 20


/*
 * Port definitions:
 *
 * Various codes for port settings: (<dir><usage><default val>: Is0 <input><spi><0, zero>)
 * another nomenclature used is <value><function><direction>, 0pO (0 (zero), port, Output),
 *    xpI (don't care, port, Input), mI (module input).
 *
 * uca0: (5c0) dock   (spi0)
 * ucb0: (5e0) mems   (spi1)  lis3dh    accel
 *                            l3g4200   gyro
 *                            lis3mdl   mag
 * uca1: (600) uSD    (spi2)
 * ucb1: (620) adc    (spi3)  ads1148
 * uca2: (640) si446x (spi4)  radio, Si4468, upg2214tb
 * ucb2: (660) temp   (i2c)   tmp102
 * uca3: (680) gps    (spi6)  Antenova M10478, ORG4472, 25WF040
 * ucb3: (6a0)
 *
 * port 1.0	0pI	si446x_irqn    		port 7.0	0pI     xin
 * 200 I .1	0pI	gyro_drdy      		      .1	0pI     xout
 * 202 O .2	0pI	             		      .2	0pI
 *       .3     0pI	usd_access_sense	      .3	0pO     usd_pwr_ena
 *       .4	0pI	adc_drdy_n     		      .4	0pI
 *       .5	1pO	usd_access_ena_n	      .5	0pO     mux2x_A
 *       .6	0pI	            		      .6	0pI
 *       .7	0pI	dock_irq       		      .7	0pI
 *
 * port 2.0	0pI	mag_drdy       		port 8.0	0pI
 *       .1	0pI	          		261 I .1	0pI
 *       .2	0pI	gyro_irq               	263 O .2	1pI     usd_csn
 *       .3	0pI	mag_irq        		      .3	0pI
 *       .4	0pI	accel_int1     		      .4	0pI
 *       .5	0pI	        		      .5	0pI
 *       .6	0pI	accel_int2		      .6	0pI
 *       .7	0pI	       			      .7	1pO     si446x_sdn
 *
 * port 3.0	0mO	dock_clk  (uca0)	port 9.0	0pI     si446x_sclk (uca2)
 *       .1	0mO	mems_mosi (ucb0)        280 I .1	0pI     temp_sda    (ucb2)
 *       .2	0mI	mems_miso (ucb0)        282 O .2	0pI     temp_scl    (ucb2)
 *       .3	0mO	mems_clk  (ucb0) 	      .3	0pI
 *       .4	0mO	dock_mosi (uca0)	      .4	0pO     si446x_mosi (uca2)
 *       .5	0mI	dock_miso (uca0)	      .5	0pI     si446x_miso (uca2)
 *       .6	0pI	usd_sclk  (uca1)       	      .6	0pI
 *       .7	0pI     adc_mosi  (ucb1)       	      .7	1pO     si446x_csn
 *
 * port  4.0	0pI	                        port 10.0	0mO     gps_clk     (uca3)
 *        .1	1pO	accel_csn (ucb0)        281 I  .1	0pO     temp_pwr
 *        .2	0pI	                        283 O  .2	0pI
 *        .3	0pI	                               .3	0pI
 *        .4	1pO	gyro_csn  (ucb0)               .4	0mO     gps_mosi   (uca3)
 *        .5	0pI	                               .5	0mI     gps_miso   (uca3)
 *        .6	1pO	mag_csn   (ucb0)               .6	1pI     adc_csn
 *        .7	0pI	adc_start                      .7	0pI
 *
 * port  5.0	0pO	mux4x_A                 port 11.0	0pO     gps_on_off 
 * 240 I  .1	0pO	mux4x_B                 2a0 I  .1	0pI
 *   2 O  .2	0pI     gps_awake                 2 O  .2	1pO     gps_resetn
 *        .3	1pO	gps_csn                        .3	0pI
 *        .4	0pI	adc_miso (ucb1)                .4	0pI
 *        .5	0pI	adc_clk  (ucb1)                .5	0pO     led_1 (red)
 *        .6	0pI	usd_mosi (uca1)                .6	0pO     led_2 (green)
 *        .7	0pI	usd_miso (uca1)                .7	0pO     led_3 (yellow)
 *
 * port  6.0	0pI                             port  J.0       0pI
 * 241 I  .1	0pI                             320 I  .1       0pO     si446x_volt_sel, (tdi/tclk)
 * 243 O  .2	1pO     pwr_3v3_ena             322 O  .2       0pI
 *        .3	0pI                                    .3       0pI     si446x_cts
 *        .4	0pO     solar_ena
 *        .5	0pI
 *        .6	0pO     bat_sense_ena
 *        .7	0pI
 */


// enum so components can override power saving,
// as per TEP 112.
enum {
  TOS_SLEEP_NONE = MSP430_POWER_ACTIVE,
};

/* @TODO@ Disable probe for XT1 support until the anomaly observed in
 * apps/bootstrap/LocalTime is resolved. */
#ifndef PLATFORM_MSP430_HAS_XT1
#define PLATFORM_MSP430_HAS_XT1 1
#endif /* PLATFORM_MSP430_HAS_XT1 */

/*
 * Platform LEDs,
 */
TOSH_ASSIGN_PIN(RED_LED,    11, 5);
TOSH_ASSIGN_PIN(GREEN_LED,  11, 6);
TOSH_ASSIGN_PIN(YELLOW_LED, 11, 7);

#endif // _H_hardware_h
