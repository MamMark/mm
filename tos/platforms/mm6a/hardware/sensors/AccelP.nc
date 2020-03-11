/*
 * Copyright 2019-2020, Eric B. Decker
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


/**
 *  Accelerometer Sensor Driver
 *  @author: Eric B. Decker
 *
 * Accelerometer ST Devices lis2dh12 monitor.
 *
 * This monitor sits on top of the Mems driver, tos/chips/mems/LisXdhP.
 * The hardware is exported via a platform hardware port, platform/<platform>/
 * hardware/mems/Accel<n>C.
 *
 * Theory of Operation:
 *
 * The lis2dh12 produces accel sensor readings at the ODR data rate,
 * (output data rate).  Each reading is composed of a 3-tuple with an X, Y,
 * and Z component.  Each component can be 8, 10, or 12 bits.  Currently we
 * us 8 bit samples (low power).  The chip has a 32 entry FIFO.  Each entry
 * is the sample 3-tuple described above, (X, Y, and Z).  The FIFO is used
 * to collect a block of sensor readings.  This block is read out in a
 * burst and written to the Collector.  This lets the chip run essentially
 * on its own, generating some amount of data, which is collected
 * periodically.  Care is needed to not overrun the FIFO.
 *
 * 1) Obtain the sensor period via RegimeCtrl.sensorPeriod().  This occurs
 *    when RegimeCtrl.regimeChange() is called on regime change.
 *
 * 2) The period is used to determine the ODR (data rate).  This determines
 *    the ingress rate of data into the FIFO.
 *
 * 3) We use a timer, called DrainTimer, to initiate data extraction.
 *    DrainTimer is set to keep the FIFO from overflowing.
 *
 * 4) When the DrainTimer expires, any complete sensor data is extracted.
 *    The lis2dh is a multiple sample sensor and requires a nsample header
 *    preprended prior to finishing with a SENSOR/ACCEL_N data (dt) header.
 *
 * 5) The complete sensor packet is handed off to the Collector.
 *
 * The timestamp (rtctime) used when the packet is collected, indicates
 * when the sensor data was extracted from the fifo.  It has no bearing
 * on the data itself.  The data rate of the incoming data determines
 * the period between readings.
 *
 * Data structures are initilized to zero by start up code.
 * Initial state is OFF (0).   DrainPeriod 0.
 */

#include <typed_data.h>
#include <panic.h>
#include <platform_panic.h>
#include "regime_ids.h"
#include "lisxdh.h"

#ifndef PANIC_SNS
enum {
  __pcode_sns = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_SNS __pcode_sns
#endif


/*
 * USE_ACCEL8,  set low power, 8 bit mode.
 * USE_ACCEL10, set normal power, 10 bit mode.
 * USE_ACCEL12, set high power, 12 bit mode.
 */

#define USE_ACCEL8

#define DEBUG

#ifdef  DEBUG

typedef struct {
  uint8_t r1;
  uint8_t r4;
  uint8_t r5;
  uint8_t status;
  uint8_t fifo_ctrl;
  uint8_t fifo_src;
} regdump_t;

#define DUMP_SIZE 256

uint32_t  reg_idx;
regdump_t regdump[DUMP_SIZE];

#endif


module AccelP {
  uses {
    interface Regime         as RegimeCtrl;
    interface MemsStHardware as Accel;
    interface SpiReg         as AccelReg;
    interface Timer<TMilli>  as DrainTimer;
    interface Collect;
    interface Panic;
  }
}
implementation {
  enum {
    FIFO_DATA_SIZE = (LISX_FIFO_SIZE + 1),
  };

  typedef enum {
    ACCEL_STATE_OFF             = 0,
    ACCEL_STATE_COLLECTING,
  } accel_state_t;

  typedef struct {
    int16_t x, y, z;
  } acceln_sample_t;

  /* module globals */
  uint32_t      m_period;
  uint32_t      m_datarate;
  accel_state_t accel_state;
  uint32_t      err_overruns;

  void accel_warn(uint8_t where, parg_t p, parg_t p1) {
    call Panic.warn(PANIC_SNS, DT_SNS_ACCEL_N8S, where, p, p1, 0);
  }

  void accel_panic(uint8_t where, parg_t p, parg_t p1) {
    call Panic.panic(PANIC_SNS, DT_SNS_ACCEL_N8S, where, p, p1, 0);
  }


  void dump_registers() {
#ifdef DEBUG
    regdump[reg_idx].r1        = call Accel.getRegister(LISX_CTRL_REG1);
    regdump[reg_idx].r4        = call Accel.getRegister(LISX_CTRL_REG4);
    regdump[reg_idx].r5        = call Accel.getRegister(LISX_CTRL_REG5);
    regdump[reg_idx].status    = call Accel.getRegister(LISX_STATUS_REG);
    regdump[reg_idx].fifo_ctrl = call Accel.getRegister(LISX_FIFO_CTRL_REG);
    regdump[reg_idx].fifo_src  = call Accel.getRegister(LISX_FIFO_SRC_REG);
    reg_idx++;
    if (reg_idx >= DUMP_SIZE)
      reg_idx = 0;
#endif
  }


  uint16_t period2datarate(uint32_t period) {
    switch (period) {
      default:   return 0;
      case 50:
      case 51:   return 20;             /* 20 Hz, 50ms period  */
      case 100:
      case 102:  return 10;             /* 10 Hz, 100ms period */
      case 1000:
      case 1024: return 1;              /* 1 Hz, 1s period     */
    }
  }

  uint32_t datarate2drain(uint16_t period) {
    switch (period) {
      default:   return 0;
      case 20:   return 1024;           /* 20 Hz, collect once/sec */
      case 10:   return 1024;           /* 10 Hz, 10/sec           */
      case  1:   return 2048;           /* 1 Hz,  2/(2 sec)        */
    }
  }

  /*
   * Drain has gone off, we want to drain the fifo.
   * Depending on the resolution we want we will generate 8 bit, 10 bit or
   * 16 bit data.
   *
   * The fifo on the accel is 32 x 16 x 3.  We add one extra to handle the
   * overflow (fifo shut down) case.  We postpend (-1, -1, -1) to the data
   * stream to indicate a break in the data stream.
   */
  event void DrainTimer.fired() {
    uint32_t datasize;
    uint32_t nsamples, fifo_len, idx;
    bool     overflowed;

    acceln_sample_t      data[FIFO_DATA_SIZE];
    dt_sensor_nsamples_t adt;           /* accel dt + nsample */

#ifdef USE_ACCEL8
    uint8_t *dp;
    uint32_t src, dest;
#endif

    memset(data, 0, sizeof(data));
    dump_registers();
    overflowed = call Accel.fifoOverflowed();
    fifo_len   = call Accel.fifoLen();
    nsamples   = fifo_len;
    idx = 0;
    if (!fifo_len) {
      /*
       * for some reason the fifo pipeline has shutdown.
       * just restart the fifo.
       */
      call Accel.restartFifo();
      dump_registers();
      return;
    }
    while (fifo_len) {
      if (idx >= LISX_FIFO_SIZE)
        break;
      call Accel.read((void *) &data[idx++], 6);
      fifo_len--;
      dump_registers();
    }
    if (overflowed && idx == LISX_FIFO_SIZE) {
      data[idx].x   = -1;
      data[idx].y   = -1;
      data[idx++].z = -1;
      nsamples++;
      call Accel.restartFifo();
      dump_registers();
    }
    datasize = nsamples * sizeof(acceln_sample_t);
    dp = (uint8_t *) data;
    src = 1;
    for (dest = 0; dest < datasize/2; dest++) {
      dp[dest] = dp[src];
      src += 2;
    }
    datasize = datasize/2;
    adt.len = sizeof(adt) + datasize;
    adt.dtype = DT_SNS_ACCEL_N8S;
    adt.sched_delta = 0;
    adt.nsamples = nsamples;
    adt.datarate = m_datarate;
    call Collect.collect((void *) &adt,  sizeof(adt),
                         (void *) &data, datasize);
  }


  event void RegimeCtrl.regimeChange() {
    uint32_t draintime;

    accel_state = ACCEL_STATE_OFF;
    call Accel.stop();
    call DrainTimer.stop();
    m_period = call RegimeCtrl.sensorPeriod(RGM_ID_ACCEL);

    if (m_period == 0)
      return;

    m_datarate = period2datarate(m_period);
    draintime  = datarate2drain(m_datarate);
    accel_state = ACCEL_STATE_COLLECTING;
    call Accel.startFifo(m_datarate);
    call DrainTimer.startPeriodic(draintime);
    dump_registers();
  }


  event void Accel.blockAvail(uint16_t nsamples, uint16_t datarate,
                              uint16_t bytes_avail) { }

  async event void Panic.hook() { }
        event void Collect.collectBooted() { }
}
