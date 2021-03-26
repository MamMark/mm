/*
 * Copyright (c) 2021 Eric B. Decker
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

configuration LSM60C {
  provides interface LSM6Hardware  as LSM6;
}
implementation {
  components Lsm6dsoxP  as LSM6Dvr;
  LSM6     = LSM6Dvr;

  components HplMems0C;
  LSM6Dvr.SpiReg         -> HplMems0C.SpiReg[MEMS0_ID_LSM6];

  components Mems0HardwareP;
  LSM6Dvr.LSM6Int1       -> Mems0HardwareP.LSM6Int1;
  LSM6Dvr.LSM6Init       <- Mems0HardwareP.LSM6Init;

  components PlatformC;
  LSM6Dvr.Platform       -> PlatformC;

  components PanicC;
  LSM6Dvr.Panic          -> PanicC;
}
