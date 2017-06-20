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
 * @author: Eric B. Decker <cire831@gmail.com>
 */

module PowerManagerP {
  provides {
    interface PowerManager;
    interface Boot as LowPowerBoot;     /* outgoing */
    interface Boot as NormalPowerBoot;  /* outgoing */
  }
  uses {
    interface Boot;
    interface Platform;
  }
}
implementation {
  /*
   * On the mm6a batt_con from the harvester isn't connected.
   *
   * Instead we look at tmp_scl.  If power is on this line should be
   * pulled up.  We do the following:
   *
   * o remember previous state,
   *     tmp_pwr_en
   *     Module state of tmp_scl and tmp_sda
   * o make tmp_scl an input
   * o turn tmp_pwr_en on
   * o check tmp_scl    if 1 -> battery is connect
   * o                  if 0 -> not connected.
   * o restore previous state.
   *
   * we wait up to 256 usecs before giving up.  When turning pwr on
   * (OFF to ON on LDO1 tmp_pwr) it is charging a cap through a resistor
   * this takes some time.
   *
   * We assume that SCL and SDA are by default set to be inputs when in
   * Port mode.  This is done in pins_init in startup.c.
   *
   * This routine can be called either bare or from within an
   * immediateRequest/Release block.
   *
   * On startup, battery_connected is called to determine our startup
   * mode.  This can be a bare call, no one else is running.
   *
   * Another use for base is when we Panic.  One of Panic's jobs is to
   * write out system state to mass storage.  However if we are in
   * low power mode we don't want to do this.  Bare call.
   *
   * The immediateRequest call is used if one needs to check power mode
   * while the system is running.  The immediateRequest (if it succeeds)
   * will lock out other users so they interfer with the status check.
   */
  async command bool PowerManager.battery_connected() {
    uint8_t  previous_pwr, previous_module;
    uint8_t  rtn;
    uint32_t t0;

    if (TMP_GET_SCL)
      return 1;

    rtn = 0;
    previous_pwr    = TMP_GET_PWR_STATE;
    previous_module = TMP_GET_SCL_MODULE_STATE;
    TMP_PINS_PORT;
    TMP_I2C_PWR_ON;
    t0 = call Platform.usecsRaw();
    while (1) {
      if (TMP_GET_SCL) {
        rtn = 1;
        break;
      }
      if (call Platform.usecsRaw() - t0 > 256)
        break;
    }
    if (previous_pwr == 0) TMP_I2C_PWR_OFF;
    if (previous_module)   TMP_PINS_MODULE;
    return rtn;
  }


  /*
   * Gets signalled on Main boot.  check to see what power
   * mode we are in currently.  If low power then signal
   * LowPowerBoot.  Otherwise signal NormalPowerBoot.
   */
  event void Boot.booted() {
    if (call PowerManager.battery_connected())
      signal NormalPowerBoot.booted();
    else
      signal LowPowerBoot.booted();
    return;
  }

  default event void LowPowerBoot.booted() { }

}
