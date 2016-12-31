/*
 * Copyright (c) 2016, Eric B. Decker
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
// #define __MSP432_DVRLIB_ROM__

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
 * MamMark Dev6a, a development board based on the TI MSP-EXP432P401R Eval
 * board.  But with the platform wirings for most major h/w subsystems from
 * the mm6a prototype.
 *
 * See the datasheet for clock speeds and flash wait states.  Also max
 * peripheral speed vs. Vcore voltage.  startup.c is definitive.
 *
 * See startup.c for definitive definitions.
 *
 *.MCLK: 16 MiHz, Vcore0, 1 Flash wait states
 *
 * DCOCLK:   16 MiHz
 * MCLK   <- DCOCLK/1
 * HSMCLK <- DCOCLK/2
 * SMCLK  <- DCOCLK/2 (limited to 12MHz (Vcore0) (8MiHz)
 * BCLK   <- LFXTCLK (32KiHz) (feeds RTC)
 * ACLK   <- LFXTCLK (32KiHz)
 *
 * DCOCLK -> MCLK, SMCLK (8 MiHz) /8 -> TMicro (1 MiHz) TA0
 * ACLK   -> TA1 (32 KiHz) -> TMilli
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
 * Various codes for port settings: (<dir><usage><default val>: Is0 <input><spi><0, zero>)
 * another nomenclature used is <value><function><direction>, 0pO (0 (zero), port, Output),
 *    xpI (don't care, port, Input), mI (module input).
 *
 * A0:
 * A1:
 * A2: gps
 * A3:
 * B0:
 * B1:
 * B2: Si4468 radio
 * B3: SD
 *
 * Port: (0x4000_4C00)
 * port 1.0	0pI	LED1           		port 7.0	0pI     SMCLK
 *  00 I .1	0pI	PB1            		 60   .1	0pI
 *  02 O .2	0pI	BSLRXD_ (A0)     	 62   .2	0pI
 *       .3     0pI	BSLTXD  (A0)                  .3	0pI
 *       .4	0pI	BSLSTE, PB2                   .4	0pI
 *       .5	0pI     BSLCLK   test_clk             .5	0pI
 *       .6	0pI	BSLSIMO  test_simo            .6	0pI
 *       .7	0pI	BSLSOMI  test_somi            .7	0pI
 *
 * port 2.0	0pI	LED2_RED                port 8.0	0pI
 *  01   .1	0pI	LED2_GREEN               61 I .1	0pI
 *  03   .2	0pI	LED2_BLUE                63 O .2	1pI
 *       .3	0pI     si446x_cts                    .3	0pI
 *       .4	0pI	                              .4	0pI
 *       .5	0pI	                              .5	0pI
 *       .6	0pI	masterRdy                     .6	0pI
 *       .7	0pI	slaveRdy                      .7	0pI
 *
 * port 3.0	0pI	gps_tp                  port 9.0	0pI
 *  20   .1	0pI	                         80 I .1	0pI
 *  22   .2	0pI	gps_out, URXD (A2)       82 O .2	0pI
 *       .3	0pI	gps_in,  UTXD (A2)            .3	0pI
 *       .4	0pI                                   .4	0pO
 *       .5	0pI	si446x_clk                    .5	0pI
 *       .6	0pI	si446x_simo                   .6	0pI
 *       .7	0pI     si446x_somi                   .7	0pI
 *
 * port  4.0	0pI	                        port 10.0	0pI     sd_csn
 *  21    .1	0pI	                         81 I  .1	0pI     sd_clk
 *  23    .2	0pI	ACLK                     83 O  .2	0pI     sd_simo
 *        .3	0pI	MCLK/RTC                       .3	0pI     sd_somi
 *        .4	0pI	HSMCLK                         .4	0pI
 *        .5	0pI	                               .5	0pI
 *        .6	0pI	                               .6	0pI
 *        .7	0pI	                               .7	0pI
 *
 * port  5.0	0pO     si446x_sdn
 *  40 I  .1	0pO     si446x_irq
 *  42 O  .2	0pI     si446x_csn
 *        .3	0pI
 *        .4	0pI
 *        .5	0pI
 *        .6	0pI
 *        .7	0pI
 *
 * port  6.0	0pI     tell                    port  J.0       0pI     LFXIN  (32KiHz)
 *  41 I  .1	0pI                             120 I  .1       0pO     LFXOUT (32KiHz)
 *  43 O  .2	0pI                             122 O  .2       0pI     HFXOUT (48MHz)
 *        .3	0pI                                    .3       0pI     HFXIN  (48MHz)
 *        .4	0pI                                    .4       0pI     TDI
 *        .5	0pI                                    .5       0pI     TDO/SWO
 *        .6	0pI     Capture, C1.1
 *        .7	0pI     Capture, C1.0
 *
 *
 * For master/slave:  (master_spi.c)
 *
 * 1.5 CLK  <--->  1.5
 * 1.6 SIMO <--->  1.6 
 * 1.7 SOMI <--->  1.7
 * 2.6 masterRdy   2.6
 * 2.7 slaveRdy    2.7
 */


/* gps - ublox - (A2) */
#define UBLOX_TP        (P3->IN)
#define UBLOX_TP_BIT    1


/* radio - si446x - (B2) */
#define SI446X_CTS_BIT  0x08
#define SI446X_CTS_P    (P2->IN & SI446X_CTS_BIT)

#define SI446X_SDN_PIN  0
#define SI446X_SDN_BIT  0x01
#define SI446X_SDN_IN   (P5->IN & SI446X_SDN_BIT)
#define SI446X_SHUTDOWN BITBAND_PERI(P5->OUT, SI446X_SDN_PIN) = 1
#define SI446X_UNSHUT   BITBAND_PERI(P5->OUT, SI446X_SDN_PIN) = 0

#define SI446X_IRQN_PIN 1
#define SI446X_IRQN_BIT (1 << SI446X_IRQN_PIN)
#define SI446X_IRQN_P   (P5->IN & SI446X_IRQN_BIT)

#define SI446X_CSN_PIN  2
#define SI446X_CSN_BIT  (1 << SI446X_CSN_PIN)
#define SI446X_CSN_IN   (P5->IN & SI446X_CSN_BIT)
#define SI446X_CSN      BITBAND_PERI(P5->OUT, SI446X_CSN_PIN)


/* micro SD */
#define SD_CSN          BITBAND_PERI(P10->OUT,0)

#define SD_ACCESS_SENSE_BIT     0x08
#define SD_ACCESS_SENSE_N       FALSE
#define SD_ACCESS_ENA_N
#define SD_PWR_ENA

#define SD_PINS_INPUT  do { } while (0)

/*
 * SD_PINS_SPI will connect the 3 spi lines on the SD to the SPI.
 * And switches the sd_csn (8.2) from input to output,  the value should be
 * a 1 which deselects the sd and tri-states.
 *
 * 3.6, CLK, 5.6-7 SDI, SDO set to SPI Module, SD_CSN switched to output
 * (assumed 1, which is CSN, CS deasserted).
 */
#define SD_PINS_SPI   do { } while (0)


#define TELL_PIN        0
#define TELL_BIT        (1 << TELL_PINT)
#define TELL            BITBAND_PERI(P6->OUT, TELL_PIN)
#define TOGGLE_TELL     do { TELL = 1; TELL = 0; } while(0)

#ifdef notdef
/* gps -gsd4e/org */
#define GSD4E_GPS_AWAKE_BIT 0x04

#define GSD4E_GPS_AWAKE         (P5IN & GSD4E_GPS_AWAKE_BIT)
#define GSD4E_GPS_SET_ONOFF     (mmP11out.gps_on_off = 1)
#define GSD4E_GPS_CLR_ONOFF     (mmP11out.gps_on_off = 0)
#define GSD4E_GPS_RESET         (mmP11out.gps_reset_n = 0)
#define GSD4E_GPS_UNRESET       (mmP11out.gps_reset_n = 1)
#define GSD4E_GPS_CSN            mmP5out.gps_csn
#endif

// enum so components can override power saving,
// as per TEP 112.
enum {
  TOS_SLEEP_NONE = MSP432_POWER_ACTIVE,
};

#endif // __HARDWARE_H__
