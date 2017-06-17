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

/*
 * Top level of the Tmp Port
 *
 * The tmp driver provides a parameterized singleton interface.  There
 * is a single driver that handles all of the temperature sensors.  The
 * parameter is the device address of the sensor.  ie.  0x48 for
 * TmpP and 0x49 for TmpX.  The address depends on how the tmp1x2 is
 * physically wired.
 *
 * The driver uses the dev_addr to address the sensor on the I2C bus and
 * uses a mapping between dev_addr and an appropriate client id (cid)
 * for accessing the resource.  Both dev_addrs and cids are unique.
 *
 * Access to the bus and power to the sensors is controlled by the
 * arbiter's ResourceDefaultOwner.
 *
 * The sensors are typically turned off and there is only one pwr
 * bit that controls power to all sensors on the bus.  This power
 * bit is controlled by the ResourceDefaultOwner wired into the
 * arbiter.  Power will be turned on as long as there is at least
 * one client using the bus.
 */

configuration TmpPC {
  provides interface SimpleSensor<uint16_t>;
  provides interface Resource;
}

implementation {

  enum {
    TMP_CLIENT = 0,
    TMP_ADDR   = 0x48,
  };

  components HplTmpC;
  SimpleSensor = HplTmpC.SimpleSensor[TMP_ADDR];
  Resource     = HplTmpC.Resource[TMP_CLIENT];
}
