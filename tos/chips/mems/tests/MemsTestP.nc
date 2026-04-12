/* tos/chips/mems/tests/MemsTestP.nc
 *
 * Copyright (c) 2019, 2021 Eric B. Decker
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

#include <lsm6dsox.h>
#include <regime_ids.h>
#include <sensor_config.h>

#ifndef PANIC_SNS
enum {
  __pcode_sns = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_SNS __pcode_sns
#endif

#define MEMS_BUF_SIZE (1024)

uint8_t mems_buf[MEMS_BUF_SIZE];
sensor_config_t cfgX[3];
uint16_t lenX;

module MemsTestP {
  uses {
    interface Boot;
    interface LSM6Hardware   as LSM6;
    interface Timer<TMilli>  as Timer;
    interface Panic;
  }
}
implementation {
  event void Boot.booted() {
    nop();
    nop();
    memset((void *) cfgX, 0, sizeof(cfgX));
    call LSM6.setMax(MEMS_BUF_SIZE);
    call LSM6.stop(TRUE);

    cfgX[0].period = SNS_12D5HZ;
    call LSM6.setConfig(LSM6DSOX_ACCEL, &cfgX[0]);
    cfgX[2].period = SNS_10HZ;
    call LSM6.setConfig(LSM6DSOX_MAG,   &cfgX[2]);
    WIGGLE_TELL;
    call LSM6.start();

    call Timer.startPeriodic(60 * 1024);
  }


  event void Timer.fired() {
    lsm6dsox_fifo_status2_t fs2;
    uint8_t  tmp;

    /* must read FIFO_STATUS1 first, (BDU) */
    tmp      = call LSM6.getReg(LSM6DSOX_FIFO_STATUS1);
    fs2.bits = call LSM6.getReg(LSM6DSOX_FIFO_STATUS2);
    lenX     = fs2.x.diff_fifo_upper << 8 | tmp;
    nop();
    call LSM6.stop(TRUE);

    cfgX[0].period = SNS_26HZ;
    call LSM6.setConfig(LSM6DSOX_ACCEL, &cfgX[0]);
    cfgX[2].period = SNS_20HZ;
    call LSM6.setConfig(LSM6DSOX_MAG,   &cfgX[2]);
    WIGGLE_TELL;
    call LSM6.start();

    call Timer.startPeriodic(60 * 1024);
  }


  uint16_t last_avail;

  event void LSM6.dataAvail() {
    uint16_t bytes_avail;

    while ((bytes_avail = call LSM6.bytesAvail())) {
      last_avail = bytes_avail;
      lenX = bytes_avail;
      nop();
      if (bytes_avail > MEMS_BUF_SIZE) {
        nop();
        call Panic.warn(PANIC_SNS, 1, bytes_avail, 0, 0, 0);
        bytes_avail = (MEMS_BUF_SIZE/7) * 7;
      }
      call LSM6.read(mems_buf, bytes_avail);
      nop();
    }
  }

  async event void Panic.hook() { }
}
