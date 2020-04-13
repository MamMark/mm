/*
 * Copyright (c) 2018 Eric B. Decker
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

/*
 * PwrGpsMems - control Gps/Mems pwr rail
 */

#include <platform_pin_defs.h>

module PwrGpsMemsP {
  provides {
    interface Init;
    interface PwrReg;
  }
}
implementation {
  command error_t Init.init() {
    signal PwrReg.pwrOn();
    return SUCCESS;
  }

  async command error_t PwrReg.pwrReq() {
    signal PwrReg.pwrOn();
    return EALREADY;                    /* no delay */
  }


  /* query power state */
  async command bool PwrReg.isPowered() {
    return TRUE;
  }


  async command void PwrReg.pwrRel() {
    signal PwrReg.pwrOff();
  }


  async command void PwrReg.forceOff()     { }

  default async event void PwrReg.pwrOn()  { }
  default async event void PwrReg.pwrOff() { }
}
