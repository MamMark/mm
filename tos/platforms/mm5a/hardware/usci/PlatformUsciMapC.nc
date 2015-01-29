/*
 * Copyright (c) 2014 Eric B. Decker
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
 */

#include "msp430usci.h"

/**
 * Connect the appropriate pins for USCI support on a msp430f5438a (also
 * works for 5438)
 *
 * @author Eric B. Decker <cire831@gmail.com>
 */

configuration PlatformUsciMapC {
} implementation {

  /* used to wire in Panic and Platform low level functions */
  components PanicC, PlatformC;

  components HplMsp430GeneralIOC as GIO;

  /* UCA0: Dock, SPI
   *
   * dock_irq           dock_clk
   * dock_sense_out     dock_do
   * dock_sense_in      dock_di
   */
  components Msp430UsciSpiA0P as SpiA0;
  SpiA0.SIMO -> GIO.UCA0SIMO;           /* dock_do  */
  SpiA0.SOMI -> GIO.UCA0SOMI;           /* dock_di  */
  SpiA0.CLK  -> GIO.UCA0CLK;            /* dock_clk */
  SpiA0.Panic -> PanicC;
  SpiA0.Platform -> PlatformC;

  /* UCA1: uSD, SPI
   *
   * sd_pwr_ena         sd_clk
   * sd_cs              sd_do
   *                    sd_di
   */
  components Msp430UsciSpiA1P as SpiA1;
  SpiA1.SIMO -> GIO.UCA1SIMO;           /* sd_do  */
  SpiA1.SOMI -> GIO.UCA1SOMI;           /* sd_di  */
  SpiA1.CLK  -> GIO.UCA1CLK;            /* sd_clk */
  SpiA1.Panic -> PanicC;
  SpiA1.Platform -> PlatformC;

  /* UCA2: radio, SPI
   *
   * radio_irq          radio_clk
   * radio_sdn          radio_do
   * radio_cs           radio_di
   * radio_volt_sel
   */
  components Msp430UsciSpiA2P as SpiA2;
  SpiA2.SIMO -> GIO.UCA2SIMO;           /* radio_do  */
  SpiA2.SOMI -> GIO.UCA2SOMI;           /* radio_di  */
  SpiA2.CLK  -> GIO.UCA2CLK;            /* radio_clk */
  SpiA2.Panic -> PanicC;
  SpiA2.Platform -> PlatformC;

  /* UCA3: gps, SPI
   *
   * gps_cs             gps_clk
   * gps_reset          gps_do
   * gps_on_off         gps_di
   * gps_wakeup
   */
  components Msp430UsciSpiA3P as SpiA3;
  SpiA3.SIMO -> GIO.UCA3SIMO;           /* gps_do  */
  SpiA3.SOMI -> GIO.UCA3SOMI;           /* gps_di  */
  SpiA3.CLK  -> GIO.UCA3CLK;            /* gps_clk */
  SpiA3.Panic -> PanicC;
  SpiA3.Platform -> PlatformC;

  /* UCB0: MEMS, SPI
   *
   * accel  P41  accel_cs       mems_clk
   * mag    P46  mag_cs         mems_do
   * gyro   P44  gyro_cs        mems_di
   *
   * accel_int1         accel_int2
   * gyro_irq           gyro_drdy
   * mag_irq            mag_drdy
   * 
   */
  components Msp430UsciSpiB0P as SpiB0;
  SpiB0.SIMO -> GIO.UCB0SIMO;           /* mems_do  */
  SpiB0.SOMI -> GIO.UCB0SOMI;           /* mems_di  */
  SpiB0.CLK  -> GIO.UCB0CLK;            /* mems_clk */
  SpiB0.Panic -> PanicC;
  SpiB0.Platform -> PlatformC;

  /* UCB1: ADC, SPI
   *
   * adc_cs             adc_clk
   * adc_drdy           adc_do
   * adc_start          adc_di
   * mux4x_{A,B}        mux2x_A
   */
  components Msp430UsciSpiB1P as SpiB1;
  SpiB1.SIMO -> GIO.UCB1SIMO;           /* adc_do  */
  SpiB1.SOMI -> GIO.UCB1SOMI;           /* adc_di  */
  SpiB1.CLK  -> GIO.UCB1CLK;            /* adc_clk */
  SpiB1.Panic -> PanicC;
  SpiB1.Platform -> PlatformC;

  /* UCB2: Temp, I2C
   *
   * temp_sda           temp_scl
   * temp_pwr
   */
  components Msp430UsciI2CB2P as I2CB2;
  I2CB2.SDA -> GIO.UCB2SDA;             /* temp_sda */
  I2CB2.SCL -> GIO.UCB2SCL;             /* temp_scl */
  I2CB2.Panic -> PanicC;
  I2CB2.Platform -> PlatformC;

  /* UCB3: Unassigned */
}
