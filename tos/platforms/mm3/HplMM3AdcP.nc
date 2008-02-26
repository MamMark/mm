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

  command void HW.power_up_sensor(uint8_t sensor, uint8_t part) {
  }

  command void HW.power_down_sensor(uint8_t sensor, uint8_t part) {
  }

  command uint8_t HW.get_dmux() {
    uint8_t temp;

    temp = mmP5out.d_mux;
    if (mmP5out.u8_inhibit)
      temp |= 0x4;
    return(temp);
  }


  command void HW.set_dmux(uint8_t val) {
    mmP5out.u8_inhibit = 1;
    mmP5out.u12_inhibit = 1;
    mmP5out.d_mux = (val & 3);
    if (val & 0x4)
      mmP5out.u12_inhibit = 0;
    else
      mmP5out.u8_inhibit = 0;
  }


  command uint8_t HW.get_smux() {
    return(mmP5out.s_mux);
  }


  command void HW.set_smux(uint8_t val) {
    mmP5out.s_mux = val;
  }


  command uint8_t HW.get_gmux() {
    return(mmP6out.g_mux);
  }


  command void HW.set_gmux(uint8_t val) {
    mmP6out.g_mux = (val & 3);
  }


#ifdef notdef
  command void HplAdc12.startConversion(){ 
    ADC12CTL0 |= ADC12ON; 
    ADC12CTL0 |= (ADC12SC + ENC); 
  }
  
  command void HplAdc12.stopConversion(){ 
    ADC12CTL0 &= ~(ADC12SC + ENC); 
    ADC12CTL0 &= ~(ADC12ON); 
  }
  
  command void HplAdc12.enableConversion(){ 
    ADC12CTL0 |= ENC; 
  }
    
  command bool HplMM3Adc.isBusy() {
    return FALSE;
  }
#endif
}
