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
 */

module PowerManagerP {
  provides interface PowerManager;
}
implementation {
  /*
   * On the dev6a there isn't a harvester nor anyway to turn
   * power off to the tmp sensor bus.  Always on.
   *
   * o remember previous state,
   *     tmp_pwr_en
   *     Module state of tmp_scl and tmp_sda
   * o make tmp_scl an input
   * o turn tmp_pwr_en on
   * o check tmp_scl    if 1 -> battery is connect   (always should rtn 1)
   * o                  if 0 -> not connected.
   * o restore previous state.
   */
  async command bool PowerManager.battery_connected() {
    uint8_t previous_pwr, previous_module;
    uint8_t rtn;

    previous_pwr    = TMP_GET_PWR_STATE;
    previous_module = TMP_GET_SCL_MODULE_STATE;
    TMP_I2C_PWR_ON;
    TMP_PINS_PORT;
    rtn = TMP_GET_SCL;
    if (previous_module)   TMP_PINS_MODULE;
    if (previous_pwr == 0) TMP_I2C_PWR_OFF;
    return FALSE;
  }
}
