/*
 * Copyright (c) 2020, Eric B. Decker
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 * See COPYING in the top level directory of this source tree.
 *
 * Contact: Eric B. Decker <cire831@gmail.com>
 */

/*
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
#include <platform.h>
#include <platform_clk_defs.h>
#include <platform_pin_defs.h>


#if !defined(__MSP432P401R__)
#warning Expected Processor __MSP432P401R__, not found
#endif

/*
 * Hardware Notes:
 *
 * MamMark MM7, a 3V3 production TAG based on the 64 pin TI MSP432P401R.
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
 * + A0: dock_comm      SPI
 * + A1: gps (ublox)    SPI
 * + A2: sd0            SPI
 * + A3: xxxx
 * + B0: mems           SPI
 *      accel/gyro: lsm6dsox  mems_id: 0 (accelgyro_csn)
 *      baro:       lps22hx   mems_id: 1 (baro_csn)
 * + B1: xxxx
 * + B2: Si4468 radio   SPI
 * + B3: tmp            I2C
 *
 *
 * Interrupt priorities: (lower is higher), default 4
 *
 * DMA:         (SD0)
 *
 * ATTN_M:      dock incoming attention interrupt.
 *
 *
 * Power notes:
 *   P1.0 pwr_tmp_en
 *   P8.0 pwr_sd0_en
 *   PJ.4 gps_pwr
 *
 * Initially (for bring up):
 *   o pwr up gps
 *   o pwr_sd0_en 0 (pwr SD down)
 *
 *
 * Operational state is given in the table below.  On a hard reset all I/O pins are put
 * into Port mode set to Input.  We use a soft reset to reset major pieces of the system
 * without changing the I/O pin state.
 *
 * dc - dock_comm
 *
 * Port: (0x4000_4C00)
 * port 1.0     0pO    pwr_tmp_en               port 7.0        0mI    gps_sclk (A1,    pm)
 *  00 I .1     0pO    batt_sense_en             60   .1        0pI    gps_tp   (ta1.1, pm)
 *  02 O .2     0pI    batt_chrg                 62   .2        0mI    gps_somi (A1,    pm)
 *       .3     0pIrd  dc_slave_rdy     tp12          .3        0mI    gps_simo (A1,    pm)
 *       .4     0pIrd  dc_attn_m_m      tp31          .4        0pI    xxxx
 *       .5     0mI    mems_sclk  (B0)                .5        0pI    xxxx
 *       .6     0mI    mems_simo  (B0)                .6        0pI    xxxx
 *       .7     0mI    mems_somi  (B0)                .7        0pI    xxxx
 *
 * port 2.0     0pIrd  dc_spi_en        tp11    port 8.0        0pO    pwr_sd0_en
 *  01   .1     0pIrd  dc_sclk (A0, pm) tp13     61 I .1        0pI    sd0_csn
 *  03   .2     0pIrd  dc_somi (A0, pm) tp27     63 O .2        0pI    xxxx
 *       .3     0pIrd  dc_simo (A0, pm) tp03          .3        0pI    xxxx
 *       .4     0pI    xxxx                           .4        0pI    xxxx
 *       .5     0mO    xxxx                           .5        0pI    xxxx
 *       .6     0pI    xxxx                           .6        0pI    xxxx
 *       .7     0pI    xxxx                           .7        0pI    xxxx
 *
 * port 3.0     0mI    sd0_somi     (A2, pm)
 *  20   .1     0mI    sd0_sclk     (A2, pm)
 *  22   .2     0mI    sd0_simo     (A2, pm)
 *       .3     1pO    radio_csn
 *       .4     0mI    radio_simo   (B2, pm)
 *       .5     0mI    radio_somi   (B2, pm)
 *       .6     0mI    radio_sclk   (B2, pm)
 *       .7     0pI    radio_irqn
 *
 * port  4.0    0pI    xxxx
 *  21    .1    0pI    xxxx
 *  23    .2    0mO    ACLK, rtc_clk
 *        .3    0pO    radio_sdn
 *        .4    0pI    radio_cts
 *        .5    0pI    radio_gp0
 *        .6    0pI    baro_int
 *        .7    1pO    baro_csn
 *
 * port  5.0    1pO    accelgyro_csn
 *  40 I  .1    0pI    accelgyro_int1
 *  42 O  .2    0pI    nc
 *        .3    0pI    nc
 *        .4    0mI    batt_sense A1 (m3)
 *        .5    0pI    gps_csn
 *        .6    0pO    gps_extint0
 *        .7    0pI    gps_txrdy   (gps_pio15)
 *
 * port  6.0    0pI    xxxx                     port  J.0       0pI     LFXIN  (32KiHz)
 *  41 I  .1    0pI    xxxx                     120 I  .1       0pO     LFXOUT (32KiHz)
 *  43 O  .2    0pI    xxxx                     122 O  .2       1pO     gps_vbkup
 *        .3    0pI    xxxx                            .3       0pI     nc
 *        .4    0pI    xxxx                            .4       0pO     gps_pwr
 *        .5    0pI    xxxx                            .5       0pI     SWO
 *        .6    0mI    tmp_sda     (B3, m2)                             SWCLK
 *        .7    0mI    tmp_scl     (B3, m2)                             SWDIO
 */

/*
 * External connections:
 *
 * DockCon (dock) - 8 pin
 *   o front side pcb, right side
 *   o numbered left to right, pin 1 on left
 *
 * dock-01 - TP34 -       2V7
 * dock-02 - TP08 -       gnd
 * dock-03 - TP12 - P1.3  dc_slave_rdy
 * dock-04 - TP31 - P1.4  dc_attn_m_n
 * dock-05 - TP11 - P2.0  dc_spi_en
 * dock-06 - TP13 - P2.1  dc_sclk
 * dock-07 - TP27 - P2.2  dc_somi
 * dock-08 - TP03 - P2.3  dc_simo
 *
 *
 * Jtag connector
 *   o front side pcb, left side
 *   o pin 1 on left, bottom side
 *   o pin 2 on left, top side
 *   o connector is standard ARM 10 pin .050" connector
 *
 * jtag-01  TP20  Vtref   2V7   jtag-02 TP23  swdio
 * jtag-03                      jtag-04 TP18  swdclk
 * jtag-05  TP22  gnd           jtag-06 TP32  swo       PJ.5
 * jtag-07                      jtag-08 nc
 * jtag-09                      jtag-10 TP28  nRESET
 *
 *
 * SD Direct Connect - 8 pin
 *
 * sddc-01 (TP36) dock_sd0_rsv1 DAT2
 * sddc-02 (TP04) dock_sd0_csn  DAT3    P8.1
 * sddc-03 (TP05) dock_sd0_di   CMD     P3.2
 * sddc-04 (TP06) dock_sd0_pwr
 * sddc-05 (TP07) dock_sd0_sclk CLK     P3.1
 * sddc-06 (TP35) gnd
 * sddc-07 (TP09) dock_sd0_do   DAT0    P3.0
 * sddc-08 (TP10) dock_sd0_rsv2 DAT1
 *
 *
 * TP03: (dock-08) dc_simo        P2.3          TP20: (jtag-01) 2V7
 * TP04: (sddc-02) dock_sd0_csn   DAT3  P8.1    TP22: (jtag-05) gnd
 * TP05: (sddc-03) dock_sd0_di    CMD   P3.2    TP23: (jtag-02) jtag swdio
 * TP06: (sddc-04) dock_sd0_pwr                 TP24:           Vbatt
 * TP07: (sddc-05) dock_sd0_sclk  CLK   P3.1
 * TP08:                          gnd
 * TP09: (sddc-07) dock_sd0_do    DAT0  P3.0    TP27: (dock-07) dc_somi        P2.2
 * TP10: (sddc-08) dock_sd0_rsv2  DAT1          TP28: (jtag-10) jtag RSTn
 * TP11: (dock-05) dc_spi_en      P2.0
 * TP12: (dock-03) dc_slave_rdy   P1.3
 * TP13: (dock-06) dc_sclk        P2.1          TP31: (dock-04) dc_attn_m_n    P1.4
 * TP14: (tmpx-04) tmp_pwr        P1.0          TP32: (jtag-06) jtag SWO       PJ.5
 * TP15: (tmpx-01) tmp_gnd        gnd
 * TP16: (tmpx-02) tmp_sda        P6.6          TP34: (dock-01) 2V7
 * TP17: (tmpx-03) tmp_scl        P6.7          TP35: (sddc-06) gnd
 * TP18: (jtag-04) jtag swclk                   TP36: (sddc-01) dock_sd0_rsv1  DAT2
 *
 *
 * JTAG/SWD to 20 pin ARM Segger Jlink  (hardwire)
 * Jlink Connector 20 pin (J)
 *
 * J-01 Vtref           dock-01 3V3             J-02 NC
 * J-03 NC    (TRST)                            J-04 gnd
 * J-05 NC    (TDI)
 * J-07 SWDIO (TMS)     dock-02 swdio           J-08 gnd
 * J-09 SWCLK (TCLK)    dock-04 swclk
 * J-11 NC    (RTCK)
 * J-13 SWO   (TDO)     dock-06 swo
 * J-15 RESET (RESET)   dock-10 RSTn            J-16
 * J-17
 * J-19                                         J-20
 */

// enum so components can override power saving,
// as per TEP 112.
enum {
  TOS_SLEEP_NONE = MSP432_POWER_ACTIVE,
};

#endif // __HARDWARE_H__
