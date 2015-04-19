/*
 * Copyright 2014-2015 (c) Eric B. Decker
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

#ifndef _H_MM_PORT_REGS_H
#define _H_MM_PORT_REGS_H

#ifndef PACKED
#define PACKED __attribute__((__packed__))
#endif

norace static volatile struct {
    uint8_t r446x_irq_n         : 1;
    uint8_t gyro_drdy           : 1;
    uint8_t p12                 : 1;
    uint8_t sd_access_sense     : 1;
    uint8_t adc_drdy_n          : 1;
    uint8_t p15                 : 1;
    uint8_t p16                 : 1;
    uint8_t dock_irq            : 1;
  } PACKED mmP1in asm("0x0200");

norace static volatile struct {
    uint8_t p10                 : 1;
    uint8_t p11                 : 1;
    uint8_t p12                 : 1;
    uint8_t p13                 : 1;
    uint8_t p14                 : 1;
    uint8_t sd_access_ena_n     : 1;
    uint8_t p16                 : 1;
    uint8_t p17                 : 1;
  } PACKED mmP1out asm("0x0202");

norace static volatile struct {
    uint8_t mag_drdy            : 1;
    uint8_t p21                 : 1;
    uint8_t gyro_irq            : 1;
    uint8_t mag_irq             : 1;
    uint8_t accel_int1          : 1;
    uint8_t p25                 : 1;
    uint8_t accel_int2          : 1;
    uint8_t p27                 : 1;
  } PACKED mmP2in asm("0x0201");

norace static volatile struct {
    uint8_t p20                 : 1;
    uint8_t p21                 : 1;
    uint8_t p22                 : 1;
    uint8_t p23                 : 1;
    uint8_t p24                 : 1;
    uint8_t p25                 : 1;
    uint8_t p26                 : 1;
    uint8_t p27                 : 1;
  } PACKED mmP2out asm("0x0203");

norace static volatile struct {
    uint8_t p30                 : 1;
    uint8_t p31                 : 1;
    uint8_t mems_di             : 1;
    uint8_t p33                 : 1;
    uint8_t p34                 : 1;
    uint8_t dock_di             : 1;
    uint8_t p36                 : 1;
    uint8_t p37                 : 1;
  } PACKED mmP3in asm("0x0220");

norace static volatile struct {
    uint8_t dock_clk            : 1;
    uint8_t mems_do             : 1;
    uint8_t p32                 : 1;
    uint8_t mems_clk            : 1;
    uint8_t dock_do             : 1;
    uint8_t p35                 : 1;
    uint8_t sd_clk              : 1;
    uint8_t adc_do              : 1;
  } PACKED mmP3out asm("0x0222");

norace static volatile struct {
    uint8_t p40                 : 1;
    uint8_t p41                 : 1;
    uint8_t p42                 : 1;
    uint8_t p43                 : 1;
    uint8_t p44                 : 1;
    uint8_t p45                 : 1;
    uint8_t p46                 : 1;
    uint8_t p47                 : 1;
  } PACKED mmP4in asm("0x0221");

norace static volatile struct {
    uint8_t p40                 : 1;
    uint8_t accel_csn           : 1;
    uint8_t p42                 : 1;
    uint8_t p43                 : 1;
    uint8_t gyro_csn            : 1;
    uint8_t p45                 : 1;
    uint8_t mag_csn             : 1;
    uint8_t adc_start           : 1;
  } PACKED mmP4out asm("0x0223");

norace static volatile struct {
    uint8_t p50                 : 1;
    uint8_t p51                 : 1;
    uint8_t gps_awake           : 1;
    uint8_t p53                 : 1;
    uint8_t adc_di              : 1;
    uint8_t p55                 : 1;
    uint8_t p56                 : 1;
    uint8_t sd_di               : 1;
  } PACKED mmP5in asm("0x0240");

norace static volatile struct {
    uint8_t mux4x_A             : 1;
    uint8_t mux4x_B             : 1;
    uint8_t p52                 : 1;
    uint8_t gps_csn             : 1;
    uint8_t p54                 : 1;
    uint8_t adc_clk             : 1;
    uint8_t sd_do               : 1;
    uint8_t p57                 : 1;
  } PACKED mmP5out asm("0x0242");

norace static volatile struct {
    uint8_t p60                 : 1;
    uint8_t p61                 : 1;
    uint8_t p62                 : 1;
    uint8_t p63                 : 1;
    uint8_t p64                 : 1;
    uint8_t p65                 : 1;
    uint8_t p66                 : 1;
    uint8_t p67                 : 1;
  } PACKED mmP6in asm("0x0241");

norace static volatile struct {
    uint8_t p60                 : 1;
    uint8_t p61                 : 1;
    uint8_t pwr_3v3_ena         : 1;
    uint8_t p63                 : 1;
    uint8_t solar_ena           : 1;
    uint8_t p65                 : 1;
    uint8_t bat_sense_ena       : 1;
    uint8_t p67                 : 1;
  } PACKED mmP6out asm("0x0243");
  
norace static volatile struct {
    uint8_t p70_xin             : 1;
    uint8_t p71_xout            : 1;
    uint8_t p72                 : 1;
    uint8_t p73                 : 1;
    uint8_t p74                 : 1;
    uint8_t p75                 : 1;
    uint8_t p76                 : 1;
    uint8_t p77                 : 1;
  } PACKED mmP7in asm("0x0260");

norace static volatile struct {
    uint8_t p70                 : 1;
    uint8_t p71                 : 1;
    uint8_t p72                 : 1;
    uint8_t sd_pwr_ena          : 1;
    uint8_t p74                 : 1;
    uint8_t mux2x_A             : 1;
    uint8_t p76                 : 1;
    uint8_t p77                 : 1;
  } PACKED mmP7out asm("0x0262");

norace static volatile struct {
    uint8_t p80                 : 1;
    uint8_t p81                 : 1;
    uint8_t p82                 : 1;
    uint8_t p83                 : 1;
    uint8_t p84                 : 1;
    uint8_t p85                 : 1;
    uint8_t p86                 : 1;
    uint8_t p87                 : 1;
  } PACKED mmP8in asm("0x0261");

norace static volatile struct {
    uint8_t p80                 : 1;
    uint8_t p81                 : 1;
    uint8_t sd_csn              : 1;
    uint8_t p83                 : 1;
    uint8_t p84                 : 1;
    uint8_t p85                 : 1;
    uint8_t p86                 : 1;
    uint8_t r446x_sdn           : 1;
  } PACKED mmP8out asm("0x0263");

norace static volatile struct {
    uint8_t p90                 : 1;
    uint8_t p91                 : 1;
    uint8_t p92                 : 1;
    uint8_t p93                 : 1;
    uint8_t p94                 : 1;
    uint8_t r446x_miso          : 1;
    uint8_t p96                 : 1;
    uint8_t p97                 : 1;
  } PACKED mmP9in asm("0x0280");

norace static volatile struct {
    uint8_t r446x_clk           : 1;
    uint8_t temp_sda            : 1;
    uint8_t temp_scl            : 1;
    uint8_t p93                 : 1;
    uint8_t r446x_mosi          : 1;
    uint8_t p95                 : 1;
    uint8_t p96                 : 1;
    uint8_t r446x_csn           : 1;
  } PACKED mmP9out asm("0x0282");

norace static volatile struct {
    uint8_t p100                : 1;
    uint8_t p101                : 1;
    uint8_t p102                : 1;
    uint8_t p103                : 1;
    uint8_t p104                : 1;
    uint8_t gps_di              : 1;
    uint8_t p106                : 1;
    uint8_t p107                : 1;
  } PACKED mmP10in asm("0x0281");

norace static volatile struct {
    uint8_t gps_clk             : 1;
    uint8_t temp_pwr            : 1;
    uint8_t p102                : 1;
    uint8_t p103                : 1;
    uint8_t gps_do              : 1;
    uint8_t p105                : 1;
    uint8_t adc_csn             : 1;
    uint8_t p107                : 1;
  } PACKED mmP10out asm("0x0283");

norace static volatile struct {
    uint8_t p110                : 1;
    uint8_t p111                : 1;
    uint8_t p112                : 1;
    uint8_t p113                : 1;
    uint8_t p114                : 1;
    uint8_t p115                : 1;
    uint8_t p116                : 1;
    uint8_t p117                : 1;
  } PACKED mmP11in asm("0x02a0");

norace static volatile struct {
    uint8_t gps_on_off          : 1;
    uint8_t p111                : 1;
    uint8_t gps_resetn          : 1;
    uint8_t p113                : 1;
    uint8_t p114                : 1;
    uint8_t led_1               : 1;    /* red    */
    uint8_t led_2               : 1;    /* green  */
    uint8_t led_3               : 1;    /* yellow */
  } PACKED mmP11out asm("0x02a2");

norace static volatile struct {
    uint8_t pj0                 : 1;
    uint8_t pj1                 : 1;
    uint8_t pj2                 : 1;
    uint8_t r446x_cts           : 1;
    uint8_t pj4                 : 1;
    uint8_t pj5                 : 1;
    uint8_t pj6                 : 1;
    uint8_t pj7                 : 1;
  } PACKED mmPJin asm("0x0320");

norace static volatile struct {
    uint8_t pj0                 : 1;
    uint8_t r446x_volt_sel      : 1;
    uint8_t pj2                 : 1;
    uint8_t tell                : 1;
    uint8_t pj4                 : 1;
    uint8_t pj5                 : 1;
    uint8_t pj6                 : 1;
    uint8_t pj7                 : 1;
  } PACKED mmPJout asm("0x0322");

/* radio - si446x */
#define R446X_CTS               mmPJin.r446x_cts
#define R446X_IRQ_N             mmP1in.r446x_irq_n
#define R446X_SDN               mmP8out.r446x_sdn
#define R446X_CSN               mmP9out.r446x_csn
#define R446X_VOLT_SEL          mmPJout.r446x_volt_sel

/* mems */
#define GYRO_DRDY               mmP1in.gyro_drdy
#define GYRO_IRQ                mmP2in.gyro_irq
#define MAG_DRDY                mmP2in.mag_drdy
#define MAG_IRQ                 mmP2in.mag_irq
#define ACCEL_INT1              mmP2in.accel_int1
#define ACCEL_INT2              mmP2in.accel_int2
#define ACCEL_CSN               mmP4out.accel_csn
#define GYRO_CSN                mmP4out.gyro_csn
#define MAG_CSN                 mmP4out.mag_csn

/* micro SD */
#define SD_ACCESS_ENA_N         mmP1out.sd_access_ena_n
#define SD_ACCESS_SENSE         mmP1in.sd_access_sense
#define SD_PWR_ENA              mmP7out.sd_pwr_ena
#define SD_CSN                  mmP8out.sd_csn

/* adc */
#define ADC_DRDY_N              mmP1in.adc_drdy_n
#define ADC_START               mmP4out.adc_start
#define ADC_CSN                 mmP10out.adc_csn

/* dock */
#define DOCK_IRQ                mmP1in.dock_irq

/* gps */
#define GSD4E_GPS_AWAKE         (mmP5in.gps_awake)
#define GSD4E_GPS_CSN           mmP5out.gps_csn
#define GSD4E_GPS_ON_OFF        mmP11out.gps_on_off
#define GSD4E_GPS_RESET         (mmP11out.gps_resetn = 0)
#define GSD4E_GPS_UNRESET       (mmP11out.gps_resetn = 1)

/* power */
#define PWR_3V3_ENA             mmP6out.pwr_3v3_ena
#define SOLAR_ENA               mmP6out.solar_ena
#define BAT_SENSE_ENA           mmP6out.bat_sense_ena
#define TEMP_PWR                mmP10out.temp_pwr

#define TELL                    mmPJout.tell
#define TOGGLE_TELL             do { TELL = 1; TELL = 0; } while(0)

#endif
