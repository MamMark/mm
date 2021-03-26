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

/*
 * The MemsMonitor sits at the top of various Mems chips and handles top level
 * interactions.  It handles configuration requests (regime changes), receiving
 * data available events and writes said data to the data stream (collection).
 *
 * Low level drivers handle initial boot and initialization, all
 * interaction with the chip (reading/writing registers), and interrupts.
 *
 * Incoming data available is signalled using an event which includes how
 * much data is available.  Data is extracted using read().
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

#define MEMS_BUF_SIZE 1024

module MemsMonitorP {
  uses {
    interface Regime;
    interface LSM6Hardware as LSM6;
    interface Collect;
    interface Panic;
  }
}
implementation {
  uint8_t mems_buf[MEMS_BUF_SIZE];

  event void Regime.regimeChange() {
    dt_header_t     hdr, *hp;
    sensor_config_t cfg[3];

    nop();
    call LSM6.stop(TRUE);               /* drain */
    cfg[0].period = call Regime.sensorPeriodUs(RGM_ID_ACCEL);
    cfg[0].fs     = 0;
    cfg[0].filter = 0;
    cfg[0].sensor_id = SNS_ID_LSM6_ACCEL;
    call LSM6.setConfig(LSM6DSOX_ACCEL, &cfg[0]);

    cfg[1].period = call Regime.sensorPeriodUs(RGM_ID_GYRO);
    cfg[1].fs     = 0;
    cfg[1].filter = 0;
    cfg[1].sensor_id = SNS_ID_LSM6_GYRO;
    call LSM6.setConfig(LSM6DSOX_GYRO, &cfg[1]);

    cfg[2].period = call Regime.sensorPeriodUs(RGM_ID_MAG);
    cfg[2].fs     = 0;
    cfg[2].filter = 0;
    cfg[2].sensor_id = SNS_ID_LIS2MDL_MAG;
    call LSM6.setConfig(LSM6DSOX_MAG, &cfg[2]);

    hp = &hdr;
    hp->len   = sizeof(hdr) + sizeof(cfg);
    hp->dtype = DT_SNS_LSM6DSOX_CFG;
    call Collect.collect((void *) &hdr, sizeof(hdr),
                         (void *) &cfg, sizeof(cfg));

    call LSM6.setMax(MEMS_BUF_SIZE);
    if (cfg[0].period || cfg[1].period || cfg[2].period)
      call LSM6.start();
  }


  event void LSM6.dataAvail() {
    dt_header_t hdr, *hp;
    uint16_t    bytes_avail;

    while ((bytes_avail = call LSM6.bytesAvail())) {
      nop();
      if (bytes_avail > MEMS_BUF_SIZE) {
        call Panic.warn(PANIC_SNS, 1, bytes_avail, 0, 0, 0);
        bytes_avail = (MEMS_BUF_SIZE/7) * 7;
      }
      call LSM6.read(mems_buf, bytes_avail);
      hp = &hdr;
      hp->len   = sizeof(hdr) + bytes_avail;
      hp->dtype = DT_SNS_LSM6DSOX;
      call Collect.collect((void *) &hdr,      sizeof(hdr),
                           (void *) &mems_buf, bytes_avail);
    }
  }

  event void Collect.collectBooted()    { }
  async event void Panic.hook()         { }
}
