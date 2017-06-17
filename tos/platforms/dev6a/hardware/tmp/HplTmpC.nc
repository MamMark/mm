/*
 * Copyright 2017 Eric B. Decker
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
  components Msp432UsciB0P, Msp432UsciI2CB0C;

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
  TmpHardwareP.Usci  -> Msp432UsciB0P;
  TmpHardwareP.Timer -> TmpTimer;
  TmpHardwareP.ResourceDefaultOwner -> ArbiterP;

  components PlatformC, PanicC;
  PlatformC.PeripheralInit  -> TmpHardwareP;
  Msp432UsciI2CB0C.Platform -> PlatformC;
  Msp432UsciI2CB0C.Panic    -> PanicC;

  components Tmp1x2P as TmpDvr;
  SimpleSensor   = TmpDvr;
  TmpDvr.I2CReg -> Msp432UsciI2CB0C;

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
