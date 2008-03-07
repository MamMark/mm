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
  command void HW.power_vref(bool up) {
  }

  command void HW.power_vdiff(bool up) {
  }

  command bool HW.isVrefPowered() {
  }

  command bool HW.isVdiffPowered() {
  }

  command void HW.toggleSal() {
  }

  command uint8_t HW.get_dmux() {
    return 0;
  }


  command void HW.set_dmux(uint8_t val) {
  }


  command uint8_t HW.get_smux() {
    return 0;
  }


  command void HW.set_smux(uint8_t val) {
  }


  command uint8_t HW.get_gmux() {
    return 0;
  }


  command void HW.set_gmux(uint8_t val) {
  }


  command void HW.power_batt(bool up) {
  }

  command void HW.power_temp(bool up) {
  }

  command void HW.power_sal(bool up) {
  }

  command void HW.power_accel(bool up) {
  }

  command void HW.power_ptemp(bool up) {
  }

  command void HW.power_press(bool up) {
  }

  command void HW.power_speed(bool up) {
  }

  command void HW.power_mag(bool up) {
  }
}
