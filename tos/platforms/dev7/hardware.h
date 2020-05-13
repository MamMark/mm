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
 * MamMark Dev7, a development board based on the TI MSP-EXP432P401R Eval
 * board.  But with the platform wirings for most major h/w subsystems from
 * the mm7 prototype.
 *
 * See the datasheet for clock speeds and flash wait states.  Also max
 * peripheral speed vs. Vcore voltage.  startup.c and platform_clk_defs.h
 * is definitive.
 *
 * startup.c for startup code and initilization.
 * platform_clk_defs.h for actual clock definitions.
 * platform_pin_defs.h for our pin assignments.
 *
 * While the dev7 defines connections for the EVK-M8GZOE evaluation board,
 * the I/O on the EVK is 1V8, the main MSP432 on the EXP board runs at 3V3.
 * It is possible to run the MSP432 at 1V8 but then the SD doesn't work.
 *
 * We are modifing a TiB (Tag in a Box) to provide a connection to an EVK
 * This provides level translators to the SD and 1V8 for the ublox GPS.
 * This modification is implemented via the mm6b platform.
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
 * A1: gps (ublox) SPI
 * A2:
 * A3: dock_comm, (not on bga), no connection
 * B0: tmp, i2c         (dma overlap with AES triggers, DMA ch 0, 1)
 * B1: adc
 * B2: Si4468 radio (SPI)
 * B3: SD0 (SPI)
 *
 * mems bus (not implemented):
 *    1.1 mems_clk
 *    1.2 mems_somi
 *    1.3 mems_simo
 *    () accel_csn    mems_id: 0
 *    () gyro_csn     mems_id: 1
 *    () mag_csn      mems_id: 2
 *
 *
 * Operational state is given in the table below.  On a hard reset all I/O pins are put
 * into Port mode set to Input.  We use a soft reset to reset major pieces of the system
 * without changing the I/O pin state.
 *
 * Port: (0x4000_4C00)
 * port 1.0     0pO     LED1                    port 7.0        0mI     gps_sclk (A1,    pm)
 *  00 I .1     1pIru   mems_sclk       PB1      60   .1        0pI     gps_tm   (ta1.1, pm)
 *  02 O .2     0pI     mems_somi       BSLRXD   62   .2        0mI     gps_somi (A1,    pm)
 *       .3     0pI     mems_simo       BSLTXD        .3        0mI     gps_simo (A1,    pm)
 *       .4     0pI                     BSLSTE        .4        0pO     dc_spi_en
 *       .5     0pI                     BSLCLK        .5        1pO     dc_attn_s_n
 *       .6     0pI     tmp_sda         BSLSIMO       .6        0pI     dc_attn_m_n
 *       .7     0pI     tmp_scl         BSLSOMI       .7        0pI
 *
 * port 2.0     0pO              (LED2_RED)     port 8.0        0mO     TA1.0 (OUT0), m2
 *  01   .1     0pO              (LED2_GREEN)    61 I .1        0pI
 *  03   .2     0pO              (LED2_BLUE)     63 O .2        0pI
 *       .3     0pI     si446x_cts                    .3        0pI
 *       .4     0pI                                   .4        0pI
 *       .5     0mO     SMCLK (pm)                    .5        0pO     tell_exception
 *       .6     0pI                                   .6        0pO     tell
 *       .7     0pI                                   .7        0pI
 *
 * port 3.0     0pI                             port 9.0        0pI
 *  20   .1     0pI     [unstabbed, nc] A2       80 I .1        0pI
 *  22   .2     0pI                              82 O .2        0pI     gps_dsel (nc)
 *       .3     0pI                                   .3        1pO     gps_csn
 *       .4     0pI     [unstabbed, nc]               .4        0pI     gps_resetn
 *       .5     0mI     si446x_clk  (B2) slave_clk    .5        0mI     dc_sclk
 *       .6     0mI     si446x_simo (B2) slave_simo   .6        0mI     dc_somi, rxd
 *       .7     0mI     si446x_somi (B2) slave_somi   .7        0mI     dc_simo, txd
 *
 * port  4.0    0pI                             port 10.0       1pIru   sd0_csn
 *  21    .1    0pI                              81 I  .1       1pIru   sd0_clk
 *  23    .2    0mO     ACLK                     83 O  .2       1pIru   sd0_simo
 *        .3    0mO     MCLK/RTC                       .3       1pIru   sd0_somi
 *        .4    0mO     HSMCLK                         .4       0pI
 *        .5    0pI                                    .5       0pI
 *        .6    0pI                                    .6       0pI
 *        .7    0pI                                    .7       0pI
 *
 * port  5.0    1pO     si446x_sdn
 *  40 I  .1    0pI     si446x_irqn
 *  42 O  .2    1pO     si446x_csn
 *        .3    0pI
 *        .4    0pI
 *        .5    0pI
 *        .6    0pI
 *        .7    0pI
 *
 * port  6.0    0pI                             port  J.0       0pI     LFXIN  (32KiHz)
 *  41 I  .1    0pI                             120 I  .1       0pO     LFXOUT (32KiHz)
 *  43 O  .2    0pI     gps_txrdy               122 O  .2       0pI     HFXOUT (48MHz)
 *        .3    0pI     adc_clk                        .3       0pI     HFXIN  (48MHz)
 *        .4    0pI     adc_simo                       .4       0pI     TDI
 *        .5    0pI     adc_somi                       .5       0pI     TDO/SWO
 *        .6    0pI
 *        .7    0pI
 */

// enum so components can override power saving,
// as per TEP 112.
enum {
  TOS_SLEEP_NONE = MSP432_POWER_ACTIVE,
};

#endif // __HARDWARE_H__
