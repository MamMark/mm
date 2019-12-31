/* tos/chips/mems/tests/MemsTestP.nc
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
 * USE_FIFO enables using the Fifos for Gyro and Accel
 */

#include <lisxdh.h>

#define USE_FIFO
#define DUMP_SIZE 256

typedef struct {
  uint8_t r1;
  uint8_t r4;
  uint8_t r5;
  uint8_t status;
  uint8_t fifo_ctrl;
  uint8_t fifo_src;
} regdump_t;

uint32_t  reg_idx;
regdump_t regdump[DUMP_SIZE];


module MemsTestP {
  uses interface Boot;
  uses interface MemsStHardware as Accel;
  uses interface Timer<TMilli>  as DrainTimer;

#ifdef notdef
  uses interface MemsStHardware as Gyro;
  uses interface Timer<TMilli>  as GyroTimer;

  uses interface MemsStHardware as Mag;
  uses interface Timer<TMilli>  as MagTimer;
#endif
}
implementation {
  typedef struct {
    int16_t x;
    int16_t y;
    int16_t z;
  } mems_sample_t;

#define SAMPLE_COUNT 60

  uint16_t m_mIdx;
  uint16_t m_gIdx;
  uint16_t m_aIdx;

  mems_sample_t   m_magSamples[SAMPLE_COUNT];
  mems_sample_t  m_gyroSamples[SAMPLE_COUNT];
  mems_sample_t m_accelSamples[SAMPLE_COUNT];


  void dump_registers() {
    regdump[reg_idx].r1        = call Accel.getRegister(LISX_CTRL_REG1);
    regdump[reg_idx].r4        = call Accel.getRegister(LISX_CTRL_REG4);
    regdump[reg_idx].r5        = call Accel.getRegister(LISX_CTRL_REG5);
    regdump[reg_idx].status    = call Accel.getRegister(LISX_STATUS_REG);
    regdump[reg_idx].fifo_ctrl = call Accel.getRegister(LISX_FIFO_CTRL_REG);
    regdump[reg_idx].fifo_src  = call Accel.getRegister(LISX_FIFO_SRC_REG);
    reg_idx++;
    if (reg_idx >= DUMP_SIZE)
      reg_idx = 0;
  }


  event void Boot.booted() {
    m_aIdx  = 0;
    reg_idx = 0;
    dump_registers();

#ifdef USE_FIFO
    call Accel.startFifo(10);
    call DrainTimer.startPeriodic(1024);
#else
    call Accel.start(10);
#endif
    dump_registers();
    nop();

#ifdef notdef
    id = call Gyro.whoAmI();
    call Gyro.config100Hz();
    call GyroTimer.startPeriodic(1000);

    id = call Mag.whoAmI();
    call Mag.config10Hz();
    call MagTimer.startPeriodic(1000);
#endif
  }


  event void DrainTimer.fired() {
#ifdef USE_FIFO
    uint32_t len;
    bool     overflowed;

    len = call Accel.fifoLen();
    if (!len) {
      /* oops, looks like the pipeline/fifo shutdown, restart it */
      call Accel.restartFifo();
      return;
    }
    overflowed = call Accel.fifoOverflowed();
    dump_registers();
    nop();
    while (len) {
      /* each entry is 6 bytes, 3 x int16_t */
      call Accel.read((void *) &(m_accelSamples[m_aIdx]), 6);
      dump_registers();
      m_aIdx++;
      len--;                            /* one entry down */
    }
    dump_registers();
    if (overflowed)
      call Accel.restartFifo();
    if (m_aIdx >= SAMPLE_COUNT) {
      call DrainTimer.stop();
      nop();
      nop();
    }
#else
    if (call Accel.dataAvail())
      call Accel.read((void *)(&m_accelSamples[m_aIdx++]), 6);
    if (m_aIdx >= SAMPLE_COUNT) {
      call DrainTimer.stop();
      nop();
      nop();
    }
#endif
  }


#ifdef notdef
  event void GyroTimer.fired() {
    if (call Gyro.dataAvail()) {
      call Gyro.read((void *)(&m_gyroSamples[m_gIdx]), 6);
      m_gIdx++;
    }
    if (m_gIdx >= SAMPLE_COUNT) {
      call GyroTimer.stop();
    }
  }


  event void MagTimer.fired() {
    if (call Mag.dataAvail()) {
      call Mag.read((void *)(&m_magSamples[m_mIdx]), 6);
      m_mIdx++;
    }
    if (m_mIdx >= SAMPLE_COUNT)
      call MagTimer.stop();
  }
#endif

  event   void     Accel.blockAvail(uint16_t nsamples, uint16_t datarate,
                              uint16_t bytes_avail) { }

}
