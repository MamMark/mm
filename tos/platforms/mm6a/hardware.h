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

#if !defined(__MSP432P401R__)
#warning Expected Processor __MSP432P401R__, not found
#endif

/*
 * Hardware Notes:
 *
 * MamMark mm6a is the production animal tag based on the TI msp432p402r
 * Cortex-4MF ARM processor.
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
 *
 * A0:
 * A1:
 * A2:
 * A3:
 * B0:
 * B1:
 * B2:
 * B3:
 *
 * Port: (0x4000_4C00)
 * port 1.0	0pI   A1 mag_drdy               port 7.0	1pI   B5 gps_cts
 *  00 I .1	0pI   B1 mag_int                 60   .1	0pI   C5 gps_tm
 *  02 O .2	0pI   C4 TP31                    62   .2	0pI   B4 gps_tx
 *       .3     0pI   D4 TP27                         .3	1pO   A4 gps_rx
 *       .4	0pI   D3                              .4	1pO   J1 adc_sclk
 *       .5	1pO   C1 mag_csn                      .5	1pO   H2 adc_simo
 *       .6	0pI   D1 accel_csn                    .6	0pO   J2 pwr_sd0_en
 *       .7	1pO   E1 accel_int2                   .7	1pI   G3 sd0_sclk
 *
 * port 2.0	0pI   E4 TP11                   port 8.0	0pI   H3
 *  01   .1	0pI   F1 adc_rdy                 61 I .1	0pI   G4 TP12 (sd0 buff en)
 *  03   .2	0pI   E3 accel_int1              63 O
 *       .3	0pI   F4 TP3
 *       .4	0pI   F3 sd0_somi
 *       .5	0pI   G1 adc_somi
 *       .6	0pO   G2 adc_start
 *       .7	1pO   H1 adc_csn
 *
 * port 3.0	1pO   J3 sd0_simo
 *  20   .1	1pO   H4 sd0_csn
 *  22   .2	0pI   G5 TP13
 *       .3	1pO   J4 radio_sdn
 *       .4	1pO   H5 radio_csn
 *       .5	1pO   G6 radio_simo
 *       .6	1pO   J5 radio_sclk
 *       .7	0pI   H6 radio_somi
 *
 * port  4.0	0pO   H9 pwr_radio_sw (voltage sel)
 *  21    .1	0pI   H8 radio_cts    (radio gpio1)
 *  23    .2	0pO   G7 batt_sense_en
 *        .3	0pO   G8 pwr_tmp_en
 *        .4	0pO   G9 pwr_3v3_en
 *        .5	0pI   F7 pwr_radio_en   (radio power switch, 1=on)
 *        .6	0pO   F8 sal_B
 *        .7	0pO   F9 sal_A
 *
 * port  5.0	0pI   E7 pwr_gps_en   (gps and mems i/o power switch)
 *  40 I  .1	0pO   E8 pwr_vel_en
 *  42 O  .2	0pO   E9 pwr_press_en
 *        .3	0pI   D7 batt_sense A2
 *        .4	0pI   D8 gyro_int2
 *        .5	0pO   C8 gps_on_off
 *        .6	1pO   D9 gyro_int1
 *        .7	0pI   C9 gyro_csn
 *
 * port  6.0	0pI   J9 radio_gp0              port  J.0       0pIru J6 LFXIN  (32KiHz)
 *  41 I  .1	0pI   H7 radio_irq              120 I  .1       0pO   J7 LFXOUT (32KiHz)
 *  43 O  .2	0pI   A9 gps_awake              122 O  .2       1pI   A6 gps_resetn
 *        .3	1pO   B9 mems_sclk                     .3       0pI   A5 gps_rts
 *        .4	1pO   A8 mems_simo                     .4       0pI   B3
 *        .5	0pI   A7 mems_somi                     .5       0pI   A3 SWO
 *        .6	1pO   B8 tmp_sda
 *        .7	1pO   B7 tmp_scl
 *
 * External connections:
 *
 * TP01: Sal Sen                                TP19: VS4 vel_pwr
 * TP02: Sal Sen                                TP20: VS3 Ain7
 * TP03:          P2.3                          TP21: VS2 Ain2
 * TP04: sd0_cs   DAT3                          TP22: VS1 gnd
 * TP05: sd0_di   CMD                           TP23: jtag swdio
 * TP06: sd0_pwr                                TP24: Vbatt
 * TP07: sd0_sclk CLK                           TP25: VS2 Ain0
 * TP08: sd0_gnd                                TP26: VS5 Ain5
 * TP09: sd0_do   DAT0                          TP27:           P1.3
 * TP10: sd0_rsv2 DAT1                          TP28: jtag RSTn
 * TP11:          P2.0                          TP29: VS2 Ain3  Press
 * TP12: ---                                    TP30: VS2 Ain4  Press
 * TP13: dock_sd_ovr                            TP31:           P1.2
 * TP14: tmp_pwr                                TP32: jtag SWO  PJ.5
 * TP15: tmp_gnd                                TP33: ---
 * TP16: tmp_sda                                TP34: 1V8
 * TP17: tmp_scl                                TP35: gnd
 * TP18: jtag swclk                             TP36: sd0 rsv1  DAT2
 */

// enum so components can override power saving,
// as per TEP 112.
enum {
  TOS_SLEEP_NONE = MSP432_POWER_ACTIVE,
};

#include <platform_pin_defs.h>

#endif // __HARDWARE_H__
