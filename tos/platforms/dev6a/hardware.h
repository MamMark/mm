/*
 * Copyright (c) 2016, 2017 Eric B. Decker, Dan J. Maltbie
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
 *
 * PLATFORM defines:
 *
 * NO_MSP_CLASSIC_DEFINES
 * __MSP432_DVRLIB_ROM__
 * __MSP432P401R__
 *
 * REQUIRE_PANIC
 * REQUIRE_PLATFORM
 *
 */

#ifndef __HARDWARE_H__
#define __HARDWARE_H__

#define NO_MSP_CLASSIC_DEFINES
//#define __MSP432_DVRLIB_ROM__

/*
 * msp432.h will pull in the right chip header using DEVICE.
 * The chip header pulls in cmsis/core_cm.4 as needed.
 */
#include <msp432.h>
#include <msp432_nesc.h>
#include <platform_clk_defs.h>
#include <platform_pin_defs.h>


#if !defined(__MSP432P401R__)
#warning Expected Processor __MSP432P401R__, not found
#endif

/*
 * Hardware Notes:
 *
 * MamMark Dev6a, a development board based on the TI MSP-EXP432P401R Eval
 * board.  But with the platform wirings for most major h/w subsystems from
 * the mm6a prototype.
 *
 * See the datasheet for clock speeds and flash wait states.  Also max
 * peripheral speed vs. Vcore voltage.  startup.c and platform_clk_defs.h
 * is definitive.
 *
 * startup.c for startup code and initilization.
 * platform_clk_defs.h for actual clock definitions.
 * platform_pin_defs.h for our pin assignments.
 */

/*
 * Memory Map:
 *
 * Flash:       0x0000_0000 - 0x0003_ffff (256K)
 *
 *              0x0020_0000 - 0x0020_3fff info memory
 *              0x0020_0000 - 0x0020_0fff Flash Boot-Override Mailbox (BSL control)
 *              0x0020_1000 - 0x0020_1fff TLV (write/erase protected)
 *              0x0020_2000 - 0x0020_2fff BSL
 *              0x0020_3000 - 0x0020_3fff BSL
 *
 * SRAM (Code)  0x0100_0000 - 0x0100_ffff code ram (64K)
 *
 * ROM:         0x0200_0000 - 0x020F_ffff (32K used, 0x8000)
 *              0x0200_0000 - 0x0200_07ff reserved
 *              0x0200_0800 - 0x0200_7fff driverlib
 *
 * SRAM:        0x2000_0000 - 0x2000_FFFF 64K
 *  bit-band    0x2200_0000 - 0x221F_FFFF 64K x 32
 *
 * Peripheral   0x4000_0000 - 0x5FFF_FFFF
 *              0x4000_0000 - 0x400F_FFFF Peripheral Region (1MB)
 *              0x4200_0000 - 0x43FF_FFFF Bit Band (32MB)
 *
 * Debug Zone:  0xE000_0000 - 0xFFFF_FFFF
 *              0xE000_0000 - 0xE000_0FFF ITM
 *              0xE000_1000 - 0xE000_1FFF DWT
 *              0xE000_2000 - 0xE000_2FFF FPB
 *              0xE000_3000 - 0xE000_DFFF reserved
 *              0xE000_E000 - 0xE000_EFFF SCS
 *              0xE004_0000 - 0xE004_0FFF TPIU
 *              0xE004_2000 - 0xE004_23FF Reset Controller
 *              0xE004_3000 - 0xE004_33FF System Controller
 *              0xE004_4000 - 0xE004_43FF System Controller
 *              0xE00F_F000 - 0xE00F_FFFF ROM Table
 *
 *
 * Port h/w addresses:
 *
 *        0x4000_0000
 * TA0:         (0000)
 * TA1:         (0400)
 * TA2:         (0800)
 * TA3:         (0C00)
 *
 * uca0:        (1000)
 * uca1:        (1400)
 * uca2:        (1800)
 * uca3:        (1C00)
 * ucb0:        (2000)
 * ucb1:        (2400)
 * ucb2:        (2800)
 * ucb3:        (2C00)
 *
 * aes256:      (3C00)
 * crc32:       (4000)
 * rtc:         (4400)
 * wdt:         (4800)
 * T32:         (C000)
 * DMA:         (E000)
 *
 *        0x4001_0000
 * PCM          (0000) power control
 * CS           (0400) clock
 * PSS          (0800) power supply system
 * FLCTL        (1000) flash control
 * ADC14        (2000)
 *
 *
 * Port definitions:
 *
 * Various codes for port settings: <value><func><dir><res>, 0pO (0 (zero), port, Output),
 *    <res> will be "ru" for pull up and "rd" for pull down.
 *    xpI (don't care, port, Input), xmI (module input).
 *    module is m for m1 (sel1 0 sel0 1), same as msp430 settings.
 *              m2 for sel1 1, sel0 0, and m3 for 11.
 *    (port, mapping), ie.  (A1, pm) says its on eUSCI-A1 and the pin is port mapped.
 *
 * A0: mems             (dma overlap with AES triggers, DMA ch 0, 1)
 * A1: SD1 (SPI)
 * A2: gps (antenova, sirfIV) UART
 *     gps_tx is on 3.2, gps_rx is on 3.3.
 * A3: do not use (not on bga)
 * B0: tmp, i2c         (dma overlap with AES triggers, DMA ch 0, 1)
 * B1: adc
 * B2: Si4468 radio (SPI)
 * B3: SD0 (SPI)
 *
 * Port: (0x4000_4C00)
 * port 1.0	0pO	LED1           		port 7.0	1pIru   sd1_clk  (A1,    pm)
 *  00 I .1	1pIru	PB1            		 60   .1	1pIru   sd1_somi (A1,    pm)
 *  02 O .2	0pI	                BSLRXD   62   .2	1pIru   sd1_simo (A1,    pm)
 *       .3     0pI	                BSLTXD        .3	0pI     gps_tm   (ta1.1, pm)
 *       .4	1pIru   dock_attn PB2   BSLSTE        .4	0pI
 *       .5	0pI     gps_cts         BSLCLK        .5	0pI
 *       .6	0pI	tmp_sda         BSLSIMO       .6	0pI
 *       .7	0pI     tmp_scl         BSLSOMI       .7	0pI
 *
 * port 2.0	0pO	dock_led (LED2_RED)     port 8.0	0mO     TA1.0 (OUT0) (m2)
 *  01   .1	0pO	         (LED2_GREEN)    61 I .1	0pI
 *  03   .2	0pO	         (LED2_BLUE)     63 O .2	0pI
 *       .3	0pI	si446x_cts                    .3	0pI
 *       .4	0pI	                              .4	0pI
 *       .5	0mO	SMCLK (pm)                    .5	0pO     tell_exception
 *       .6	0pI	                              .6	0pO     tell
 *       .7	0pI	                              .7	0pI
 *
 * port 3.0	0pI	                        port 9.0	0pI
 *  20   .1	0pI	[unstabbed, nc] A2       80 I .1	0pI
 *  22   .2	0pI	gps_tx (A2)   URXD       82 O .2	0pI
 *       .3	1pO	gps_rx (A2)   UTXD            .3	0pI
 *       .4	0pI     [unstabbed, nc]               .4	1pIru   sd1_csn
 *       .5	0mO	si446x_clk  (B2) slave_clk    .5	0pI     [unstabbed]
 *       .6	0mO	si446x_simo (B2) slave_simo   .6	0pI     [unstabbed]
 *       .7	0mIrd   si446x_somi (B2) slave_somi   .7	0pI
 *
 * port  4.0	0pO	gps_on_off               port 10.0	1pIru   sd0_csn
 *  21    .1	0pI	                         81 I  .1	1pIru   sd0_clk
 *  23    .2	0mO	ACLK                     83 O  .2	1pIru   sd0_simo
 *        .3	0mO	MCLK/RTC                       .3	1pIru   sd0_somi
 *        .4	0mO	HSMCLK                         .4	0pI
 *        .5	0pI	gps_rts                        .5	0pI
 *        .6	0pI	                               .6	0pI
 *        .7	0pI	                               .7	0pI
 *
 * port  5.0	1pO     si446x_sdn
 *  40 I  .1	0pI     si446x_irqn
 *  42 O  .2	1pO     si446x_csn
 *        .3	0pI
 *        .4	0pI
 *        .5	0pI
 *        .6	0pI
 *        .7	0pI
 *
 * port  6.0	1pI     gps_resetn              port  J.0       0pI     LFXIN  (32KiHz)
 *  41 I  .1	0pI     gps_awake               120 I  .1       0pO     LFXOUT (32KiHz)
 *  43 O  .2	0pI                             122 O  .2       0pI     HFXOUT (48MHz)
 *        .3	0pI                                    .3       0pI     HFXIN  (48MHz)
 *        .4	0pI                                    .4       0pI     TDI
 *        .5	0pI                                    .5       0pI     TDO/SWO
 *        .6	0pI     Capture, C1.1
 *        .7	0pI     Capture, C1.0
 */

// enum so components can override power saving,
// as per TEP 112.
enum {
  TOS_SLEEP_NONE = MSP432_POWER_ACTIVE,
};

#endif // __HARDWARE_H__
