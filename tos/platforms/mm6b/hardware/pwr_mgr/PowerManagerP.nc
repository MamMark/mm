/*
 * Copyright (c) 2017-2018 Eric B. Decker
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 * See COPYING in the top level directory of this source tree.
 *
 * Contact: Eric B. Decker <cire831@gmail.com>
 */

#include <platform.h>
#include <overwatch.h>

#ifndef PWR_CHECK_TIME
// 1024 mis/sec * 60sec/min
#define PWR_CHECK_TIME (60 * 1024)
#endif

module PowerManagerP {
  provides {
    interface PowerManager;
    interface Boot as LowPowerBoot;     /* outgoing */
    interface Boot as OKPowerBoot;      /* outgoing */
  }
  uses {
    interface Boot;                     /* incoming */

    interface OverWatch;
    interface Timer<TMilli> as PwrTimer;
    interface Platform;
    interface Panic;
  }
}
implementation {
  /*
   * On the mm6b batt_con from the harvester isn't connected.
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


  event void PwrTimer.fired() {
    if (call PowerManager.battery_connected()) {
      /*
       * after power comes back up, continue with what we
       * were doing, but start out with a clean reboot.
       *
       * The reboot will use what ever is in owcb.ow_req,
       * ow_boot_mode, and owt_action.
       *
       * We also set the reboot reason to ORR_LOW_PWR to indicate
       * a LOW_PWR to OK_PWR transition.
       *
       * The FAULT_LOW_PWR bit will get reset following snag
       * and record via the reboot record.  See Collect.
       */
      call OverWatch.reboot(ORR_LOW_PWR);
      /* no return */
    }
  }


  /*
   * Gets signalled on Main boot.  check to see what power
   * mode we are in currently.  If low power then signal
   * LowPowerBoot.  Otherwise signal OKPowerBoot.
   */
  event void Boot.booted() {
    if (call PowerManager.battery_connected()) {
      signal OKPowerBoot.booted();
      return;
    }
    call OverWatch.setFault(OW_FAULT_LOW_PWR);
    call PwrTimer.startPeriodic(PWR_CHECK_TIME);
  }

  default event void LowPowerBoot.booted() {
    call Panic.panic(PANIC_PWR, 1, 0, 0, 0, 0);
  }

  async event void Panic.hook() { }
}
