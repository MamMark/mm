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

#ifndef __PLATFORM_PORT_DEFS__
#define __PLATFORM_PORT_DEFS__

/*
 * For master/slave:  (master_spi.c)
 *
 * 1.5 CLK  <--->  1.5
 * 1.6 SIMO <--->  1.6
 * 1.7 SOMI <--->  1.7
 * 2.6 masterRdy   2.6
 * 2.7 slaveRdy    2.7
 */

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

#define SD_PINS_INPUT  do { P10->SEL0 = 0; } while (0)

/*
 * SD_PINS_SPI will connect the 3 spi lines on the SD to the SPI.
 * And switches the sd_csn (10.0) from input to output,  the value should be
 * a 1 which deselects the sd and tri-states.
 *
 * 10.1, CLK, 10.2-3 SDI, SDO set to SPI Module, SD_CSN switched to output
 * (assumed 1, which is CSN, CS deasserted).
 */
#define SD_PINS_SPI   do { P10->SEL0 = 0x0E; } while (0)


#define TELL_PORT       P8
#define TELL_PIN        6
#define TELL_BIT        (1 << TELL_PIN)
#define TELL            BITBAND_PERI(TELL_PORT->OUT, TELL_PIN)
#define TOGGLE_TELL     TELL ^= 1;
#define TELL0           TELL_PORT->OUT = 0;
#define TELL1           TELL_PORT->OUT = TELL_BIT;
#define WIGGLE_TELL     do { TELL1; TELL0; } while(0)


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

#endif    /* __PLATFORM_PORT_DEFS__ */
