/*
 * Copyright (c) 2012, 2015, 2017 Eric B. Decker
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

#include <TinyError.h>
#include "tmp1x2.h"

/*
 * Driver for the TI tmp102 and tmp112.  Supports 1 or more of these
 * devices on a single I2C bus.
 *
 * We use I2CReg to access the small simple registers in the sensor.
 * I2CReg always runs to completion.  However, typically the power to the
 * bus is off and one needs to wait 26-35 ms before the first tmp sample is
 * done after power has come up.  This is handled by the Arbiter and
 * ResourceDefaultOwner (RDO).  When the Resource.granted signal occurs,
 * the first tmp sample has been completed in theory.
 *
 * SimpleSensor uses a device addr (dev_addr).  This gets mapped to the
 * appropriate client_id for use in the Resource arbitration system.  The
 * mapping between cid and sensor address is shown below.
 *
 * The return value from the Read (readDone) is 16 bits.  We run in 12
 * bit mode (not extended (EM)).  This gives us +/- 128 degrees C.  Each
 * bit is 0.0625 degrees C.  The 12 bits are left aligned into 16 bits.
 *
 * We typically run the I2C bus at 400KHz which gives us a 20us byte time.
 * It just doesn't make any sense to run this with interrupts.  That is why
 * we use the I2CReg interface which runs to completion.
 */

module Tmp1x2P {

  /*
   * dev_addr is as follows:
   *
   * cid = client id, devaddr = device addr
   *
   * cid    devaddr
   *   0    0x48        1001000 for ADD0 connected to ground
   *   1    0x49        1001001 for ADD0 connected to V+
   *   2    0x4a        1001010 for ADD0 connected to SDA
   *   3    0x4b        1001011 for ADD0 connected to SCL
   */

  provides interface SimpleSensor<uint16_t>[uint8_t dev_addr];
  uses {
    interface I2CReg;
    interface Resource[uint8_t cid];
  }
}
implementation {

/*
 * CONFIG gets shoved at the config register after we are done taking a
 * reading.  It will shut the Tmp sensor down.  This is the lowest
 * power state until the default owner pulls power.
 */

#define CONFIG (TMP1X2_CONFIG_RES_3 | TMP1X2_CONFIG_SD | \
                TMP1X2_CONFIG_4HZ | TMP1X2_CONFIG_AL)

#define TMP_ADDR_BASE 0x48
#define DEV_ADDR(cid) ((cid) + TMP_ADDR_BASE)
#define CID(dev_addr) ((dev_addr) - TMP_ADDR_BASE)

  command bool SimpleSensor.isPresent[uint8_t dev_addr]() {
    bool rtn;

    if (call Resource.immediateRequest[CID(dev_addr)]()) {
      /*
       * if immediate request fails can't get the bus
       * just FAIL.
       */
      return 0;                         /* say no one home */
    }
    rtn = call I2CReg.slave_present(dev_addr);
    call Resource.release[CID(dev_addr)]();
    return rtn;
  }


  command error_t SimpleSensor.read[uint8_t dev_addr]() {
    return call Resource.request[CID(dev_addr)]();
  }


  event void Resource.granted[uint8_t cid]() {
    uint16_t d;
    error_t rtn;

    rtn = call I2CReg.reg_read16(DEV_ADDR(cid), TMP1X2_TEMP, &d);
    signal SimpleSensor.readDone[DEV_ADDR(cid)](rtn, d);
  }

  default event void SimpleSensor.readDone[uint8_t dev_addr] (error_t error, uint16_t data) { }

  default async command error_t Resource.request[uint8_t cid]()          { return FAIL; }
  default async command error_t Resource.immediateRequest[uint8_t cid]() { return FAIL; }
  default async command error_t Resource.release[uint8_t cid]()          { return FAIL; }

}
