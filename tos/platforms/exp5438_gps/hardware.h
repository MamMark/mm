/*
 * Copyright (c) 2012, 2014-2015 Eric B. Decker
 * Copyright (c) 2009-2010 People Power Co.
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
 * @author Peter Bigot
 * @author Eric B. Decker <cire831@gmail.com>
 *
 * 04/29/2014: Eric B. Decker.  Added SiLabs Si4463 E10-M4463D 433MHz
 * radio module (A3, P10).
 *
 * 2014: Eric B. Decker.  Modified MM5t platform, removed Accel and
 * Tmp to build a module with the Antenova M1048 GPS module (B1, P3, P5).
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
 * port 1.0	0pO	led0    		port 4.0	0pO    gps_on_off
 *       .1	0pO	led1    		      .1	1pO    gps_reset_n (nRST)
 *       .2	0pI	r446x_cts      		      .2	1pO    gps_csn (nRTS)
 *       .3     0pI	          		      .3	0pI    gps_awake
 *       .4	0pI	r446x_irqn     		      .4	0pI
 *       .5	0pI	             		      .5	0pI
 *       .6	0pI	            		      .6	0pI
 *       .7	0pI	         		      .7	0pI
 *
 * port 2.0	0pI	          		port 5.0	0pI
 *       .1	0pI	          		      .1	0pI
 *       .2	0pI	                 	      .2	0pI
 *       .3	0pI	           		      .3	0pI
 *       .4	0pI	        		      .4	0pI    gps_somi (tx,   B1SOMI)
 *       .5	0pI	        		      .5	0pI    gps_sclk (nCTS, B1CLK)
 *       .6	0pI	       			      .6	0pI
 *       .7	0pI	       			      .7	0pI
 *
 * port 3.0	0pI	      			port 6.0	0pI
 *       .1	0pI	                    	      .1	0pI
 *       .2	0pI	                    	      .2	0pI
 *       .3	0pI	                    	      .3	0pI
 *       .4	0pO	led2   			      .4	0pI
 *       .5	0pI	       			      .5	0pI
 *       .6	0pI	                	      .6	0pI
 *       .7	0pI	gps_simo (rx, B1SIMO)  	      .7	0pI
 *
 * port 10.0	0pO	r446x_sclk (a3sclk)	port 11.0	0pI
 *        .1	0pI	(nc) xi2c_sda (b3sda)  	       .1	0pI
 *        .2	0pI	(nc) xi2c_scl (b3scl)  	       .2	0pI
 *        .3	0pO     tell               	       .3	0pI
 *        .4	0pI	r446x_mosi (a3mosi)	       .4	0pI
 *        .5	0pI	r446x_miso (a3miso)	       .5	0pI
 *        .6	1p0	r446x_sdn              	       .6	0pI
 *        .7	1pO	r446x_csn		       .7	0pI
 */


// enum so components can override power saving,
// as per TEP 112.
enum {
  TOS_SLEEP_NONE = MSP430_POWER_ACTIVE,
};

/* Use the PlatformAdcC component, and enable 8 pins */
//#define ADC12_USE_PLATFORM_ADC 1
//#define ADC12_PIN_AUTO_CONFIGURE 1
//#define ADC12_PINS_AVAILABLE 8

/* @TODO@ Disable probe for XT1 support until the anomaly observed in
 * apps/bootstrap/LocalTime is resolved. */
#ifndef PLATFORM_MSP430_HAS_XT1
#define PLATFORM_MSP430_HAS_XT1 1
#endif /* PLATFORM_MSP430_HAS_XT1 */

/*
 * Platform LEDs,
 *
 * Eval board has two leads, P1.0 and P1.1.
 * We keep the Yellow LED on P4.6, which is on the header
 * but isn't connected to anything.
 */
TOSH_ASSIGN_PIN(RED_LED,    1, 0);
TOSH_ASSIGN_PIN(GREEN_LED,  1, 1);
TOSH_ASSIGN_PIN(YELLOW_LED, 3, 4);

#endif // _H_hardware_h
