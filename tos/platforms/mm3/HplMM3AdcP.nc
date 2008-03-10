/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT 
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED 
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, 
 * OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY 
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE 
 * USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/**
 * The HplMM3Adc interface exports low-level access to control registers
 * of the Mam_Mark ADC subsystem.
 *
 * @author Eric B. Decker
 */

#include "hardware.h"
#include "sensors.h"

module HplMM3AdcP {
  provides interface HplMM3Adc as HW;
}

implementation {
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

  command bool HW.isVrefPowered() {
    return (mmP4out.vref_off == 0);
  }

  command bool HW.isVdiffPowered() {
    return (mmP4out.vdiff_off == 0);
  }

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

    temp = mmP2out.smux_low2;
    if (mmP3out.smux_a2)
      temp |= 4;
    return(temp);
  }


  command void HW.set_smux(uint8_t val) {
    mmP2out.smux_low2 = (val & 3);
    mmP3out.smux_a2   = ((val & 4) == 4);
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
    mmP3out.tmp_on = 1;
  }

  command void HW.temp_off() {
    mmP3out.tmp_on = 0;
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
    mmP1out.speed_off = 0;
  }

  command void HW.speed_off() {
    mmP1out.speed_off = 1;
  }

  command void HW.mag_on() {
    mmP6out.mag_xy_off = 0;
    mmP6out.mag_z_off  = 0;
  }

  command void HW.mag_off() {
    mmP6out.mag_xy_off = 1;
    mmP6out.mag_z_off  = 1;
  }
}
