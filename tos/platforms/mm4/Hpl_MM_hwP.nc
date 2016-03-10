/*
 * Copyright (c) 2008, 2010, Eric B. Decker
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

/**
 * The Hpl_MM_hw interface exports low-level access to control registers
 * of the mammark h/w.
 *
 * It works for both the MM3 and MM4 hardware as h/w differences are reflected
 * in defines controlled by port definition files in the platform directory.
 *
 * @author Eric B. Decker
 */

#include "hardware.h"
#include "sensors.h"
#include "gps.h"

module Hpl_MM_hwP {
  provides interface Hpl_MM_hw as HW;
}

implementation {
  MSP430REG_NORACE(P3SEL);
  MSP430REG_NORACE(P5DIR);

  command void HW.vref_on() {
    mmP4out.vref_off = 0;
  }

  command void HW.vref_off() {
    mmP4out.vref_off = 1;
  }

  command void HW.vdiff_on() {
    mmP4out.vdiff_off = 0;
  }

  command void HW.vdiff_off() {
    mmP4out.vdiff_off = 1;
  }

#ifdef notdef
  command bool HW.isVrefPowered() {
    return (mmP4out.vref_off == 0);
  }

  command bool HW.isVdiffPowered() {
    return (mmP4out.vdiff_off == 0);
  }
#endif

  command void HW.toggleSal() {
    mmP2out.salinity_pol_sw ^= 1;
  }


  command uint8_t HW.get_dmux() {
    uint8_t temp;

    temp = mmP1out.dmux;
    if (mmP2out.u8_inhibit)
      temp |= 0x4;
    return(temp);
  }


  command void HW.set_dmux(uint8_t val) {
    mmP2out.u8_inhibit = 1;
    mmP2out.u12_inhibit = 1;
    mmP1out.dmux = (val & 3);
    if (val & 0x4)
      mmP2out.u12_inhibit = 0;
    else
      mmP2out.u8_inhibit = 0;
  }


  command uint8_t HW.get_smux() {
    uint8_t temp;

    temp = SMUX_LOW2;
    if (SMUX_A2)
      temp |= 4;
    return(temp);
  }


  command void HW.set_smux(uint8_t val) {
    SMUX_LOW2 = (val & 3);
    SMUX_A2   = ((val & 4) == 4);
  }
  
  command uint8_t HW.get_gmux() {
    return(mmP4out.gmux);
  }

  command void HW.set_gmux(uint8_t val) {
    mmP4out.gmux = (val & 3);
  }

  command void HW.batt_on() {
    mmP4out.extchg_battchk = 1;
  }

  command void HW.batt_off() {
    mmP4out.extchg_battchk = 0;
  }

  command void HW.temp_on() {
    TMP_ON = 1;
  }

  command void HW.temp_off() {
    TMP_ON = 0;
  }

  command void HW.sal_on() {
    mmP1out.salinity_off = 0;
  }

  command void HW.sal_off() {
    mmP1out.salinity_off = 1;
  }

  command void HW.accel_on() {
    mmP2out.accel_wake = 1;
  }

  command void HW.accel_off() {
    mmP2out.accel_wake = 0;
  }

  command void HW.ptemp_on() {
    mmP1out.press_off = 1;
    mmP1out.press_res_off= 0;
  }

  command void HW.ptemp_off() {
    mmP1out.press_res_off = 1;
  }

  command void HW.press_on() {
    mmP1out.press_res_off= 1;
    mmP1out.press_off = 0;
  }

  command void HW.press_off() {
    mmP1out.press_off = 1;
  }

  command void HW.speed_on() {
    mmP6out.speed_off = 0;
  }

  command void HW.speed_off() {
    mmP6out.speed_off = 1;
  }

  command void HW.mag_on() {
    mmP6out.mag_xy_off = 0;
    mmP6out.mag_z_off  = 0;
  }

  command void HW.mag_off() {
    mmP6out.mag_xy_off = 1;
    mmP6out.mag_z_off  = 1;
  }

  async command void HW.gps_on() {
    mmP4out.gps_off = 0;
    GPS_PINS_UART;		// switch pins over to the module
  }

  async command void HW.gps_off() {
    GPS_PINS_INPUT;
    mmP4out.gps_off = 1;
  }
}
