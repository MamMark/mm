/*
 * Copyright 2017 Eric B. Decker
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
 * SimpleSensor uses a parameterized interface that is a device address.
 * This maps to the underlying arbiter as a client id (cid).  The mapping
 * between dev_addr and cid is done in the TmpDvr (Tmp1x2).
 *
 * 0x48 -> 0
 * 0x49 -> 1
 * 0x4A -> 2
 * 0x4B -> 3
 *
 * The number of sensors is defined in hardware_tmp.h.
 */

#include <hardware_tmp.h>

configuration HplTmpC {
  provides {
    interface Resource[uint8_t cid];
    interface SimpleSensor<uint16_t>[uint8_t dev_addr];
  }
}
implementation {
  components MainC;
  components Msp432UsciB3P, Msp432UsciI2CB3C;

  components new FcfsResourceQueueC(HW_TMP_MAX_SENSORS) as QueueC;
  components new ArbiterP(HW_TMP_MAX_SENSORS)           as ArbiterP;
  MainC.SoftwareInit -> QueueC;
  ArbiterP.Queue     -> QueueC;
  Resource = ArbiterP;

#ifdef TRACE_RESOURCE
  components TraceC;
  ArbiterP.Trace -> TraceC;
#endif

  components new TimerMilliC() as TmpTimer;
  components     TmpHardwareP;
  TmpHardwareP.Usci  -> Msp432UsciB3P;
  TmpHardwareP.Timer -> TmpTimer;
  TmpHardwareP.ResourceDefaultOwner -> ArbiterP;

  components PlatformC, PanicC;
  PlatformC.PeripheralInit  -> TmpHardwareP;
  Msp432UsciI2CB3C.Platform -> PlatformC;
  Msp432UsciI2CB3C.Panic    -> PanicC;
  TmpHardwareP.Platform     -> PlatformC;

  components Tmp1x2P as TmpDvr;
  SimpleSensor   = TmpDvr;
  TmpDvr.I2CReg -> Msp432UsciI2CB3C;

  TmpDvr.Resource[HW_TMP_DEV_48_CID] -> ArbiterP.Resource[HW_TMP_DEV_48_CID];   /* 0 */
  TmpDvr.Resource[HW_TMP_DEV_49_CID] -> ArbiterP.Resource[HW_TMP_DEV_49_CID];   /* 1 */

#ifdef notdef
  /*
   * if more tmp sensors are on the bus, you can crank
   * HW_TMP_MAX_SENSORS up
   */
  TmpDvr.Resource[HW_TMP_DEV_4A_CID] -> ArbiterP.Resource[HW_TMP_DEV_4A_CID];   /* 2 */
  TmpDvr.Resource[HW_TMP_DEV_4B_CID] -> ArbiterP.Resource[HW_TMP_DEV_4B_CID];   /* 3 */
#endif
}
