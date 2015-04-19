/*
 * Copyright 2012, 2014-2015 (c) Eric B. Decker
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
 * @author Eric B. Decker
 */

#ifndef _H_MM_PORT_REGS_H
#define _H_MM_PORT_REGS_H

#ifndef PACKED
#define PACKED __attribute__((__packed__))
#endif

  static volatile struct {
    uint8_t p10             : 1;
    uint8_t p11 	    : 1;
    uint8_t p12 	    : 1;
    uint8_t p13		    : 1;
    uint8_t p14 	    : 1;
    uint8_t p15		    : 1;
    uint8_t p16		    : 1;
    uint8_t p17		    : 1;
  } PACKED mmP1in asm("0x0200");

  static volatile struct {
    uint8_t led0            : 1;	/* red, led1 */
    uint8_t led1	    : 1;	/* yellow, led2 */
    uint8_t p12             : 1;
    uint8_t p13		    : 1;
    uint8_t p14		    : 1;
    uint8_t p15		    : 1;
    uint8_t p16		    : 1;
    uint8_t p17		    : 1;
  } PACKED mmP1out asm("0x0202");

  static volatile struct {
    uint8_t p20		    : 1;
    uint8_t p21_left	    : 1;
    uint8_t p22_right	    : 1;
    uint8_t p23_select	    : 1;
    uint8_t p24_up	    : 1;
    uint8_t p25_down	    : 1;
    uint8_t p26_sw1	    : 1;
    uint8_t p27_sw2	    : 1;
  } PACKED mmP2in asm("0x0201");

  static volatile struct {
    uint8_t p20		    : 1;
    uint8_t p21		    : 1;
    uint8_t p22		    : 1;
    uint8_t p23		    : 1;
    uint8_t p24		    : 1;
    uint8_t p25		    : 1;
    uint8_t p26		    : 1;
    uint8_t p27		    : 1;
  } PACKED mmP2out asm("0x0203");

  static volatile struct {
    uint8_t p30		    : 1;
    uint8_t p31		    : 1;
    uint8_t p32		    : 1;
    uint8_t p33		    : 1;
    uint8_t p34		    : 1;
    uint8_t p35		    : 1;
    uint8_t p36		    : 1;
    uint8_t gps_mosi	    : 1;	/* x.y 3.7, spi B1MOSI */
  } PACKED mmP3out asm("0x0222");

  static volatile struct {
    uint8_t p40		    : 1;
    uint8_t p41		    : 1;
    uint8_t p42		    : 1;
    uint8_t gps_awake	    : 1;	/* x.y 4.3, input */
    uint8_t p44		    : 1;
    uint8_t p45		    : 1;
    uint8_t p46		    : 1;
    uint8_t p47		    : 1;
  } PACKED mmP4in asm("0x0221");


norace static volatile struct {
    uint8_t gps_on_off	    : 1;	/* x.y 4.0, output */
    uint8_t gps_reset_n	    : 1;	/* x.y 4.1, output */
    uint8_t gps_csn	    : 1;	/* x.y 4.2, output */
    uint8_t p43		    : 1;
    uint8_t p44		    : 1;
    uint8_t p45		    : 1;
    uint8_t p46		    : 1;
    uint8_t p47		    : 1;
  } PACKED mmP4out asm("0x0223");

  static volatile struct {
    uint8_t p50		    : 1;
    uint8_t p51		    : 1;
    uint8_t p52		    : 1;
    uint8_t p53		    : 1;
    uint8_t gps_miso	    : 1;	/* x.y 5.4, spi B1MISO */
    uint8_t gps_sclk	    : 1;	/* x.y 5.5, spi B1SCLK */
    uint8_t p56		    : 1;
    uint8_t p57		    : 1;
  } PACKED mmP5out asm("0x0242");

  static volatile struct {
    uint8_t p60		    : 1;
    uint8_t p61		    : 1;
    uint8_t p62		    : 1;
    uint8_t p63		    : 1;
    uint8_t p64		    : 1;
    uint8_t p65		    : 1;
    uint8_t p66		    : 1;
    uint8_t p67		    : 1;
  } PACKED mmP6out asm("0x0243");
  
  static volatile struct {
    uint8_t p70_xin	    : 1;
    uint8_t p71_xout	    : 1;
    uint8_t p72		    : 1;
    uint8_t p73		    : 1;
    uint8_t p74_a12	    : 1;
    uint8_t p75_a13	    : 1;
    uint8_t p76_a14	    : 1;
    uint8_t p77_a15	    : 1;
  } PACKED mmP7out asm("0x0262");

  static volatile struct {
    uint8_t p80		    : 1;
    uint8_t p81		    : 1;
    uint8_t p82		    : 1;
    uint8_t p83		    : 1;
    uint8_t p84		    : 1;
    uint8_t p85		    : 1;
    uint8_t p86		    : 1;
    uint8_t p87		    : 1;
  } PACKED mmP8out asm("0x0263");

  static volatile struct {
    uint8_t p90		    : 1;
    uint8_t p91		    : 1;
    uint8_t p92		    : 1;
    uint8_t p93		    : 1;
    uint8_t p94		    : 1;
    uint8_t p95		    : 1;
    uint8_t p96		    : 1;
    uint8_t p97		    : 1;
  } PACKED mmP9out asm("0x0282");

norace
  static volatile struct {
    uint8_t accel_sclk	    : 1;	/* p10 0, spi a3sclk        */
    uint8_t xi2c_sda	    : 1;	/* p10 1, i2c b3sda         */
    uint8_t xi2c_scl	    : 1;	/* p10 2, i2c b3scl         */
    uint8_t tell	    : 1;	/* p10 3, used for triggers */
    uint8_t accel_mosi	    : 1;	/* p10 4, spi a3mosi        */
    uint8_t accel_miso	    : 1;	/* p10 5, spi a3miso (input)*/
    uint8_t p106	    : 1;
    uint8_t accel_csn	    : 1;	/* p10 7, chip select       */
  } PACKED mmP10out asm("0x0283");

  static volatile struct {
    uint8_t p110	    : 1;
    uint8_t p111	    : 1;
    uint8_t p112	    : 1;
    uint8_t p113	    : 1;
    uint8_t p114	    : 1;
    uint8_t p115	    : 1;
    uint8_t p116	    : 1;
    uint8_t p117	    : 1;
  } PACKED mmP11out asm("0x02A2");

/* gps -gsd4e/org */
#define GSD4E_GPS_AWAKE     (mmP4in.gps_awake)
#define GSD4E_GPS_SET_ONOFF (mmP4out.gps_on_off = 1)
#define GSD4E_GPS_CLR_ONOFF (mmP4out.gps_on_off = 0)
#define GSD4E_GPS_RESET     (mmP4out.gps_reset_n = 0)
#define GSD4E_GPS_UNRESET   (mmP4out.gps_reset_n = 1)
#define GSD4E_GPS_CSN        mmP4out.gps_csn

#define TELL                 mmP10out.tell
#define TOGGLE_TELL          do { TELL = 1; TELL = 0; } while(0)

#endif
