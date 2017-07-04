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
 */

/*
 * Clocking Overview:
 *
 * There is a 32KiHz crystal connected to LFXT (XT1).  This provides a
 * stable fairly accurate clocking source that drives the main 1mis ticker
 * (Tmilli).  It is connected to the TA1 16 bit timer.  This is the clock
 * that is used when the main system is sleeping.  It is also used for
 * various h/w timestamping functions (like the GPS TM timestamp).
 *
 * It ticks in jiffies.  1 jiffy = 1/32768 = 30.52 us.
 *
 * The 32KiHz crystal also drives the Real Time Clock (RTC).  The RTC is
 * clock from BCLK which we configure to be driven by LFXTCLK.  The RTC
 * has compensation for crystal offset error and crystal temperature drift
 * so can be different than TA1 above.
 *
 * The main CPU and other systems are driven by DCOCLK.  DCOCLK is a tuneable
 * clock driven by internal msp432 clocking circuits.  The frequency we are
 * using is set by the define MSP432_CLK below.
 *
 * There is an ARM Timer32 module that is driven by DCOCLK.  We use it to
 * provide a 1us ticker when the main DCOCLK is running.  Note that when
 * the main system is sleeping this clock will NOT be running.
 *
 * SMCLK is always DCOCLK/2.  This a h/w limitation.  The peripheral clocks
 * are limited to DCOCLK/2 when DCOCLK is a maximum.  We just play it safe
 * and use DCOCLK/2.  SMCLK is used to drive all the peripherals and timers.
 * (not TA1 which is driven by LFXTCLK).
 */

#ifndef __PLATFORM_CLK_DEFS__
#define __PLATFORM_CLK_DEFS__

#define MSP432_CLK 16777216
//#define MSP432_CLK 48000000

/*
 * The following defines control low level hw init.
 *
 * MSP432_DCOCLK       16777216 | 33554432 | 48000000   dcoclk  see below.
 * MSP432_VCORE:       0 or 1                           core voltage
 * MSP432_FLASH_WAIT:  number of wait states, [0-3]     needed wait states
 * MSP432_T32_PS       (1 | 16 | 32)                    prescale divisor for t32
 * MSP432_T32_USEC_DIV (1 | 3)                          convert raw Tx to us or uis
 * MSP432_T32_ONE_SEC  1048576 | 2097152 | 3000000      ticks for one sec (t32)
 * MSP432_TA_ID        TIMER_A_CTL_ID__<n>              n is the divider
 * MSP432_TA_EX        TIMER_A_EX0_IDEX__<n>            extra ta divisor <n>
 *
 * SMCLK is always DCOCLK/2.  SMCLK/(TA_ID * TA_EX) should be around 1MHz/1MiHz.
 * SD's are clocked at SMCLK/2 or SMCLK (if SMCLK < 12MHz)
 * GPS UART baud is determined by which config in GPSnHardwareP.
 *
 * SDs can typically be clocked up to 25MHz.
 * Radio (si4468) up to 10MHz.
 * Mems
 *
 * Peripheral divisors.  These determine divisors buried in configuration structures
 * that are fed to the eUSCI hardware.
 *
 * SD_DIV       spi bus running the SD hard drive.
 * RADIO_DIV    spi bus running the radio chip
 * MEMS_DIV     spi bus running to the mems sensors.
 * TMP_DIV      used for the i2c bus running the tmpP and tmpX temp sensors
 */

#define T32_DIV_1   TIMER32_CONTROL_PRESCALE_0
#define T32_DIV_16  TIMER32_CONTROL_PRESCALE_1
#define T32_DIV_256 TIMER32_CONTROL_PRESCALE_2

#if MSP432_CLK == 48000000
#warning using Main Clock of 48MHz
#define MSP432_DCOCLK      48000000UL
#define MSP432_VCORE       1
#define MSP432_FLASH_WAIT  1
#define MSP432_T32_PS      T32_DIV_16
#define MSP432_T32_USEC_DIV 3
#define MSP432_T32_ONE_SEC 3000000UL
#define MSP432_TA_ID   TIMER_A_CTL_ID__ ## 8
#define MSP432_TA_EX TIMER_A_EX0_IDEX__ ## 3
#define MSP432_SD_DIV      1
#define MSP432_RADIO_DIV   1
#define MSP432_MEMS_DIV    1
#define MSP432_TMP_DIV     60
#undef  USECS_BINARY

#elif MSP432_CLK == 33554432
#warning using Main Clock of 32MiHz
#define MSP432_DCOCLK      33554432UL
#define MSP432_VCORE       1
#define MSP432_FLASH_WAIT  1
#define MSP432_T32_PS      T32_DIV_16
#define MSP432_T32_USEC_DIV 2
#define MSP432_T32_ONE_SEC 2097152
#define MSP432_TA_ID   TIMER_A_CTL_ID__ ## 8
#define MSP432_TA_EX TIMER_A_EX0_IDEX__ ## 2
#define MSP432_SD_DIV      1
#define MSP432_RADIO_DIV   1
#define MSP432_MEMS_DIV    1
#define MSP432_TMP_DIV     42
#define USECS_BINARY       1

#elif MSP432_CLK == 24000000
#warning using Main Clock of 24MHz
#define MSP432_DCOCLK      24000000UL
#define MSP432_VCORE       1
#define MSP432_FLASH_WAIT  0
#define MSP432_T32_PS      T32_DIV_1
#define MSP432_T32_USEC_DIV 24
#define MSP432_T32_ONE_SEC 24000000UL
#define MSP432_TA_ID   TIMER_A_CTL_ID__ ## 4
#define MSP432_TA_EX TIMER_A_EX0_IDEX__ ## 3
#define MSP432_SD_DIV      1
#define MSP432_RADIO_DIV   1
#define MSP432_MEMS_DIV    1
#define MSP432_TMP_DIV     30
#undef  USECS_BINARY

#elif MSP432_CLK == 16777216
#define MSP432_DCOCLK      16777216UL
#define MSP432_VCORE       0
#define MSP432_FLASH_WAIT  1
#define MSP432_T32_PS      T32_DIV_16
#define MSP432_T32_USEC_DIV 1
#define MSP432_T32_ONE_SEC 1048576UL
#define MSP432_TA_ID   TIMER_A_CTL_ID__ ## 8
#define MSP432_TA_EX TIMER_A_EX0_IDEX__ ## 1
#define MSP432_SD_DIV      1
#define MSP432_RADIO_DIV   1
#define MSP432_MEMS_DIV    1
#define MSP432_TMP_DIV     21
#define USECS_BINARY       1

#elif MSP432_CLK == 10000000
#warning using Main Clock of 10MHz
#define MSP432_DCOCLK      10000000UL
#define MSP432_VCORE       0
#define MSP432_FLASH_WAIT  0
#define MSP432_T32_PS      T32_DIV_1
#define MSP432_T32_USEC_DIV 10
#define MSP432_T32_ONE_SEC 10000000UL
#define MSP432_TA_ID   TIMER_A_CTL_ID__ ## 1
#define MSP432_TA_EX TIMER_A_EX0_IDEX__ ## 5
#define MSP432_SD_DIV      1
#define MSP432_RADIO_DIV   1
#define MSP432_MEMS_DIV    1
#define MSP432_TMP_DIV     13
#undef  USECS_BINARY

#else
#error MSP432_CLK has an unrecognized speed
#endif

#define USECS_VAL       (1-(TIMER32_1->VALUE))/MSP432_T32_USEC_DIV

/*
 * to convert Jiffies to usecs (decimal).
 *
 *   T_us = (T_j * MULT_JIFFIES_TO_US) / DIV_JIFFIES_TO_US
 */
#define MULT_JIFFIES_TO_US 30518
#define DIV_JIFFIES_TO_US  1000

#endif    /* __PLATFORM_CLK_DEFS__ */
