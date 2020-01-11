/*
 * Copyright (c) 2019 Eric B. Decker
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

#include <platform_pin_defs.h>

configuration Accel0C {
  provides {
    interface MemsStHardware  as Accel;
    interface SpiReg          as AccelReg;
  }
}
implementation {
  components LisXdhP  as AccelDvr;      /* accel chip driver */
  Accel               =  AccelDvr;

  components Mems0HardwareP;
#ifdef notdef
  AccelDvr.AccelInt1  -> Mems0HardwareP;
#endif

  components HplMems0C;
  AccelReg            =  HplMems0C.SpiReg[MEMS0_ID_ACCEL];
  AccelDvr.SpiReg     -> HplMems0C.SpiReg[MEMS0_ID_ACCEL];

  Mems0HardwareP.AccelReg -> HplMems0C.SpiReg[MEMS0_ID_ACCEL];
}
