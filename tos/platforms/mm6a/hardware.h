/*
 * Copyright (c) 2017 Eric B. Decker
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
#define __MSP432_DVRLIB_ROM__

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
 *    (port, mapping), ie.  (A1, pm) says its on eUSCI-A1 and the pin is port mapped.
 *
 * A0: gps       uart   m10478  (dma overlap/AES, DMA ch 0, 1)
 *                      25wf040 external eeprom
 * A1: dock/sd1  spi
 * A2: sd0       spi
 * A3: --- do not use
 * B0: adc       spi    ads1148 (dma overlap/AES, DMA ch 0, 1)
 * B1: mems      spi
 *                      accel: lis2dx12
 *                      gyro:  l3gd20h
 *                      mag:   lis3mdl
 * B2: radio     spi    si4468
 * B3: tmp       i2c    tmp102
 *
 * Power notes:
 *
 * P5.0 pwr_gps_mems_1V8_en
 * P4.3 pwr_tmp_en (LDO1, U4)
 * P4.4 pwr_3v3_en (LDO2, U4)
 * P7.6 pwr_sd0_en
 * P4.5 pwr_radio_en
 * P4.0 pwr_radio_3V3
 * P5.1 pwr_vel_en
 * P5.2 pwr_press_en
 *
 * Initially (for bring up):
 * o pwr up gps/mems
 * o 3V3 rail (for SD).
 * o pwr_sd0_en 0 (pwr SD down)
 *
 * gps/mems power.  P5.0 controls the power switch for the gps/mems 1V8 rail.  If this is
 * powered off all gps/mems pins should be inputs or low.
 *
 * Port: (0x4000_4C00)
 * port 1.0	0pI   A1 mag_drdy               port 7.0	1pIru B5 gps_cts(*)
 *  00 I .1	0pI   B1 mag_int                 60   .1	0pI   C5 gps_tm     (PM_TA1.1)
 *  02 O .2	0pO   C4 dock_sw_led_attn  TP31  62   .2	0pI   B4 gps_tx     (PM_UCA0RXD)
 *       .3     0pO   D4 sd1_csn           TP27       .3	1pO   A4 gps_rx     (PM_UCA0TXD)
 *       .4	0pI   D3                              .4	1pO   J1 adc_sclk   (PM_UCB0CLK)
 *       .5	1pO   C1 mag_csn                      .5	1pO   H2 adc_simo   (PM_UCB0SIMO)
 *       .6	1pO   D1 accel_csn                    .6        0pO   J2 pwr_sd0_en
 *       .7	0pI   E1 accel_int2                   .7	1mO   G3 sd0_sclk   (PM_UCA2CLK)
 *
 * P1.2 tell,   P1.3 tell_exception   for debugging and bring up.  Both on TPs on the edge.
 *
 * port 2.0	1pO   E4 sd1_sclk (PM_UCA1CLK) TP11
 *  01   .1	0pI   F1 adc_rdy
 *  03   .2	0pI   E3 accel_int1
 *       .3	1pO   F4 sd1_simo (PM_UCA1SIMO) TP3
 *       .4	0mI   F3 sd0_somi (PM_UCA2SOMI)
 *       .5	0pI   G1 adc_somi (PM_UCB0SOMI)
 *       .6	0pO   G2 adc_start
 *       .7	1pO   H1 adc_csn
 *
 * port 3.0	1mO   J3 sd0_simo    (PM_UCA2SIMO)
 *  20   .1	1pO   H4 sd0_csn
 *  22   .2	0pI   G5 sd1_somi    (PM_UCA1SOMI) TP13
 *       .3	1pO   J4 radio_sdn
 *       .4	1pO   H5 radio_csn
 *       .5	1pO   G6 radio_simo  (PM_UCB2SIMO)
 *       .6	1pO   J5 radio_sclk  (PM_UCB2CLK)
 *       .7	0pI   H6 radio_somi  (PM_UCB2SOMI)
 *
 * port  4.0	0pO   H9 pwr_radio_3V3 (vsel_1v8_3v3), 1 says 3V3, 0 1V8
 *  21    .1	0pI   H8 radio_cts    (radio gp1)
 *  23    .2	0pO   G7 batt_sense_en
 *        .3	0pO   G8 pwr_tmp_en (LDO1, U4)
 *        .4	1pO   G9 pwr_3v3_en (LDO2, U4)
 *        .5	1pO   F7 pwr_radio_en   (1=on)
 *        .6	0pO   F8 sal_B
 *        .7	0pO   F9 sal_A
 *
 * port  5.0	1pO   E7 pwr_gps_mems_1V8_en   (gps pwr, mems 1V8 pwr, mems 1V8 i/o)
 *  40 I  .1	0pO   E8 pwr_vel_en
 *  42 O  .2	0pO   E9 pwr_press_en
 *        .3	0pI   D7 batt_sense A2
 *        .4	0pI   D8 gyro_int2              port 8.0	0pI   H3
 *        .5	0pO   C8 gps_on_off              61 I .1	0pO   G4 dock_sd0_override  TP12
 *        .6	0pI   D9 gyro_int1               63 O
 *        .7	1pO   C9 gyro_csn
 *
 * port  6.0	0pI   J9 radio_gp0              port  J.0       0pI   J6 LFXIN  (32KiHz)
 *  41 I  .1	0pI   H7 radio_irqn             120 I  .1       0pO   J7 LFXOUT (32KiHz)
 *  43 O  .2	0pI   A9 gps_awake              122 O  .2       1pO   A6 gps_resetn
 *        .3	1pO   B9 mems_sclk  (B1)               .3       0pI   A5 gps_rts(*)
 *        .4	1pO   A8 mems_simo  (B1)               .4       0pI   B3
 *        .5	0pI   A7 mems_somi  (B1)               .5       0pI   A3 SWO
 *        .6	0pI   B8 tmp_sda(**)(B3)
 *        .7	0pI   B7 tmp_scl(**)(B3)
 *
 * (*): gps_cts, gps_rts: The gps chip (the antenova M10478) needs gps_cts pulled high
 *      and gps_rts floating to come up in UART mode.  The mm6a implements this by
 *      using an internal pull up on gps_cts and leaves gps_rts as an input.
 *
 * (**) P6.6, 7: I2C SDA/SCL should not get any internal pull ups or pull downs.
 *      They are externally connected to pull ups connected to the 1V8_H bus
 *      from the harvester.  They will be pull downs when _H power is off (Harvester).
 *
 * External connections:
 *
 * DockCon (dock) - 14 pin (just to right of ADC0)
 * pin 1 far right top side, odd numbers on top, evens on bottom.
 *
 * dock-01 - TP28 - jtag RSTn                   dock-02 - TP11 - dock_sd1_sclk     P2.0
 * dock-03 - TP23 - jtag swdio                  dock-04 - TP27 - dock_sd1_csn      P1.3
 * dock-05 - TP32 - jtag swo                    dock-06 - TP31 - dock_sw_led_attn  P1.2
 * dock-07 - TP18 - jtag swclk                  dock-08 - TP03 - dock_sd1_simo     P2.3
 * dock-09 - TP13 - dock_sd1_somi P3.2          dock-10 - TP12 - dock_sd0_override
 * dock-11 - TP24 - Vbatt                       dock-12 - TP08 - gnd
 * dock-13 - nc   - key                         dock-14 - TP34 - 1V8
 *
 *
 * SD Direct Connect - 8 pin (to the right of DC connector), bottom of board
 * pin 1 to the right
 *
 * sddc-01 (TP36) dock_sd0_rsv1  DAT2
 * sddc-02 (TP04) dock_sd0_csn  DAT3
 * sddc-03 (TP05) dock_sd0_di   CMD
 * sddc-04 (TP06) dock_sd0_pwr
 * sddc-05 (TP07) dock_sd0_sclk CLK
 * sddc-06 (TP35) gnd
 * sddc-07 (TP09) dock_sd0_do   DAT0
 * sddc-08 (TP10) dock_sd0_rsv2 DAT1
 *
 * TP01: (saln-02) Sal Sen                      TP19: (alog-08) VS4 vel_pwr
 * TP02: (saln-01) Sal Sen                      TP20: (alog-05) VS3 Ain7
 * TP03: (dock-08) dock_sd1_simo P2.3           TP21: (alog-04) VS2 Ain2
 * TP04: (sddc-02) dock_sd0_csn  DAT3           TP22: (alog-01) VS1 gnd
 * TP05: (sddc-03) dock_sd0_di   CMD            TP23: (dock-03) jtag swdio
 * TP06: (sddc-04) dock_sd0_pwr                 TP24: (dock-11) Vbatt
 * TP07: (sddc-05) dock_sd0_sclk CLK            TP25: (alog-03) VS2 Ain0
 * TP08: (dock-12) gnd                          TP26: (alog-06) VS5 Ain6
 * TP09: (sddc-07) dock_sd0_do   DAT0           TP27: (dock-04) dock_sd1_csn P1.3
 * TP10: (sddc-08) dock_sd0_rsv2 DAT1           TP28: (dock-01) jtag RSTn
 * TP11: (dock-02) dock_sd1_sclk P2.0           TP29: (alog-07) VS2 Ain3  Press
 * TP12: (dock-10) dock_sd0_override            TP30: (alog-02) VS2 Ain5  Press
 * TP13: (dock-09) dock_sd1_somi P3.2           TP31: (dock-06) dock_sw_led_attn P1.2
 * TP14: (tmpx-04) tmp_pwr                      TP32: (dock-05) jtag SWO  PJ.5
 * TP15: (tmpx-01) tmp_gnd  (gnd)               TP33: ---
 * TP16: (tmpx-02) tmp_sda                      TP34: (dock-14) 1V8
 * TP17: (tmpx-03) tmp_scl                      TP35: (sddc-06) gnd
 * TP18: (dock-07) jtag swclk                   TP36: (sddc-01) dock_sd0_rsv1  DAT2
 *
 *
 * JTAG/SWD to 20 pin ARM Segger Jlink  (hardwire)
 * Jlink Connector 20 pin (J)
 *
 * J-01 Vtref           dock-14 1V8             J-02 NC
 * J-03 NC    (TRST)                            J-04 gnd
 * J-05 NC    (TDI)
 * J-07 SWDIO (TMS)     dock-03 swdio           J-08 gnd
 * J-09 SWCLK (TCLK)    dock-07 swclk
 * J-11 NC    (RTCK)
 * J-13 SWO   (TDO)
 * J-15 RESET (RESET)   dock-01 RSTn
 * J-17
 * J-19
 */

// enum so components can override power saving,
// as per TEP 112.
enum {
  TOS_SLEEP_NONE = MSP432_POWER_ACTIVE,
};

#endif // __HARDWARE_H__
