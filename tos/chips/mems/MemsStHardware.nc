/* tos/chips/mems/MemsStHardware.nc
 *
 * Copyright (c) 2019 Eric B. Decker
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
 * h/w interface for Mems sensors.
 * Initially written for ST Mems sensors but should extend to other
 * hardware.
 *
 * written for ST register based SPI sensors.  Such as lis2dh12 (accel),
 * l3gd20h (gyro), and lis3mdl (magnetometer).  All I/O assumes direct
 * register access.
 *
 * All calls are currently task level only and effectively
 * atomic with respect to other MemsBus access.  No arbitration is
 * needed.
 */

interface MemsStHardware {
  /**
   * whoAmI: return chip identifier
   */
  command uint8_t  whoAmI();

  /**
   * dataAvail: return TRUE if a new sample is available.
   */
  command bool     dataAvail();

  /**
   * read: read buflen bytes from the sensor.
   */
  command void     read(uint8_t *buf, uint8_t bufLen);

  /**
   * getStatus: get a status byte from the sensor.
   */
  command uint16_t getStatus();

  /**
   * getRegister: retrieve register from sensor.
   * setRegister: set register on sensor.
   */
  command uint8_t  getRegister(uint8_t reg);
  command void     setRegister(uint8_t reg, uint8_t val);

  /**
   * start: turn the sensor on at a given datarate.
   * stop:  turn the sensor off.
   */
  command void     start(uint16_t datarate);
  command void     stop();

  /**
   * Fifo Control.
   *
   * startFifo():      start the chip with Fifo access.
   * restartFifo():    after the fifo stalls, restart it.
   * fifoOverflowed(): return TRUE if the fifo has been overrun.
   * fifoLen():        return current fifo length.
   */
  command void     startFifo(uint16_t datarate);
  command void     restartFifo();
  command bool     fifoOverflowed();
  command uint8_t  fifoLen();

  /**
   * blockAvail: underlying signal indicating new sensor data
   *             is available.
   *
   * output:    nsamples        number of samples available
   *            datarate        datarate, interval between samples
   *                            in Hertz.
   *            bytes_avail     number of bytes available from the
   *                            sample pipeline.
   *
   * User will need to use MemsStHardware.read() to obtain the sensor data.
   */
  event   void     blockAvail(uint16_t nsamples, uint16_t datarate,
                              uint16_t bytes_avail);
}
