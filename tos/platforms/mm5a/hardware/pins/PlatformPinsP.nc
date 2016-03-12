/*
 * Copyright (c) 2014, 2016 Eric B. Decker
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

module PlatformPinsP {
  provides interface Init;
}

implementation {
  command error_t Init.init() {

    /*
     * Main default pin setting is all input after reset
     * except for the follow exceptions where we have hardware
     * hooked up.
     */

    /*
     * sd_access_ena_n = 1, no access, disconnects uSD
     * uSD is powered off.
     */
    P1OUT = 0x20;
    P1DIR = 0x20;                     /* P1.5 output */

    /* P2 all input */

    /*
     * MEMS I/O is powered (1.8V) but main MEMS power (3.3 rail) is off.
     * Set the I/O for normal (SPI, UCB0) operation.
     *
     * Dock, MEMS, ADC, and uSD are all powered down on start up
     * so make everything an input to avoid powering anything.
     *
     * ADC is powered by the 3.3 rail which is off, so we must make
     * any connections be inputs to avoid powering the ADC chip.
     *
     * USCI should be in reset on POR, what values will the output
     * lines be set to?  FIXME.
     */
    P3OUT = 0x00;
    P3DIR = 0x1b;
    P3SEL = 0x3f;

    /* accel_csn = gyro_csn = mag_csn = 1
     * adc_start = 0, input
     */
    P4OUT = 0x52;
    P4DIR = 0x52;

    /* mux4x_A = mux4x_B = 0, gps_csn = 1,
     * adc_di = adc_clk = 0, sd_do = sd_di = 0
     * ADC and uSD are off, so make connections be inputs
     */
    P5OUT = 0x08;
    P5DIR = 0x0b;

    /* pwr_3v3_ena = 1, solar_ena = 0, bat_sense_ena = 0 */
    P6OUT = 0x04;
    P6DIR = 0x54;

    /* sd_pwr_ena = 0, mux2x_A = 0 */
    P7OUT = 0x00;
    P7DIR = 0x28;

    /* sd_csn = 1, radio_sdn = 0
     * make sd_csn and input FIXME (should get handled
     * by setting OE* of u37 high (to disconnect).
     */
    P8OUT = 0x84;
    P8DIR = 0x80;

    /* radio_csn = 1, clk, sda, scl, do = 0
     * di input, Temp down, inputs
     */
    P9OUT = 0x80;
    P9DIR = 0x90;

    /* adc_csn = 1 input; temp_pwr = 0 (off)
     * clk, do, 0; di input
     */
    P10OUT = 0x40;
    P10DIR = 0x13;

    /* gps_on_off = 0, gps_resetn = 1 */
    P11OUT = 0x04;
    P11DIR = 0x05;

    /* radio_volt_sel = 0, 1.8V */
    PJOUT  = 0x00;
    PJDIR  = 0x02;
    return SUCCESS;
  }
}
