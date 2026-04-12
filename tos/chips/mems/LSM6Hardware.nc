/* tos/chips/mems/LSM6Hardware.nc
 *
 * Copyright (c) 2021 Eric B. Decker
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
 * h/w interface for STMicro LSM6 based Mems sensors.
 *
 * STMicro LSM6 hardware implement multisensor complex sensor arrays.
 * Data capture is assumed to be via a FIFO queue.
 *
 * Data coming from the LSM6 is typed.  One byte of <type> followed by
 * 6 data bytes.  When data is available, blockAvail(bytes_avail) will
 * be signaled.  bytes_avail will be a multiple of 7.  Data from the sensor
 * complex is read using read(buf, len).
 *
 * All calls are currently task level only and effectively
 * atomic with respect to other MemsBus access.  No arbitration is
 * needed.
 */

#include <sensor_config.h>

interface LSM6Hardware {
  /**
   * setConfig: configure the LSM6 complex.
   *
   * input:     lsm6_sensor     which sensor
   *            cfg             pointer to config block
   *
   * returns:   SUCCESS
   *            FAIL
   *
   * lsm6_sensor is currently the same as LSM6DSOX_DT.
   *
   * configures a given sensor in the complex.
   */
  command void setConfig(uint8_t lsm6_sensor, sensor_config_t *cfg);

  /**
   * setMax: set max block that can be accepted.
   *
   * input:     maxlen  maximum size.
   */
  command void setMax(uint16_t maxlen);

  /**
   * start: turns the sensor complex on.  Uses last configuration loaded.
   * stop:  turns all sensors off.
   */
  command void start();
  command void stop(bool drain);

  /**
   * bytesAvail: return number of bytes in fifo.
   *
   * This lets the upper layer ask repeatedly how many bytes
   * are left in the fifo.
   */
  command uint16_t bytesAvail();

  /**
   * read: read len bytes from the sensor.
   *
   * reads len bytes from the sensor complex.
   * sensor data is 7 byte elements, 1 byte <type>,
   * 6 bytes <data>.
   */
  command void    read(uint8_t *buf, uint16_t len);

  command uint8_t getReg(uint8_t reg);
  command void    setReg(uint8_t reg, uint8_t val);

  /**
   * dataAvail: underlying signal indicating new sensor data
   *            is available.
   *
   * User will need to use LSM6Hardware.read() to obtain the sensor data.
   */
  event void dataAvail();
}
