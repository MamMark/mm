/* tos/chips/mems/Lsm6dsoxP.nc
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
 * low level driver for the ST LSM6DSOX complex sensor array.
 *
 * The LSM6DSOX is run in fifo mode and all data is modelled as a
 * stream of bytes.  Each element consists of 6 bytes and a type
 * byte that denotes what kind of data it is.
 *
 * See platform initialization for appropriate startup code.
 * see <platform>/hardware/sensors/Mems<n>HardwareP.
 */

#include <lsm6dsox.h>
#include <lis2mdl.h>
#include <sensor_config.h>

#ifndef PANIC_SNS
enum {
  __pcode_sns = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_SNS __pcode_sns
#endif

#define LSM6_DEBUG

#ifdef  LSM6_DEBUG
#define LSM6_CAP_SIZE 16

typedef struct {
  uint32_t ts;
  uint8_t where;
  uint8_t fc1;
  uint8_t fc2;
  uint8_t fc3;
  uint8_t fc4;
  uint8_t fs1;
  uint8_t fs2;
  uint8_t int1c;
  uint8_t c1_xl;
  uint8_t c2_gy;
  uint8_t c3_c;
  uint8_t c4_c;
  uint8_t c6_c;
  uint8_t c9_xl;
  uint8_t master_config;
  uint8_t s0_add;
  uint8_t s0_reg;
  uint8_t s0_config;
  uint8_t s1_add;
  uint8_t s1_reg;
  uint8_t s1_config;
  uint8_t sx_other;
  uint8_t dw_s0;
  uint8_t status_master;
} lsm6state_t;

uint32_t    lsm6state_idx;
lsm6state_t lsm6state[LSM6_CAP_SIZE];
uint8_t     last_mag_config[3];
uint8_t     last_mag_status;

#endif


module Lsm6dsoxP {
  provides {
    interface Init         as LSM6Init;
    interface LSM6Hardware as LSM6;
  }
  uses {
    interface MemsStInterrupt as LSM6Int1;
    interface SpiReg;
    interface Platform;
    interface Panic;
  }
}
implementation {

#ifdef PLATFORM_LSM6_I2C_PU_EN
#define SET_SHUB_PU(mc) mc.x.shub_pu_en = 1;
#else
#define SET_SHUB_PU(mc) mc.x.shub_pu_en = 0;
#endif

  uint16_t        maxdata;
  sensor_config_t gyro_config;
  sensor_config_t accel_config;
  sensor_config_t mag_config;


  /*
   * convert period to an odr value - XL
   *
   * values assume High Performance mode is disabled. (normal mode)
   * lower power.
   */
  uint8_t period2odr_xl(uint32_t period) {
    switch(period) {
      default:
        call Panic.panic(PANIC_SNS, 16, period, 0, 0, 0);
        return 0;
      case SNS_1D6HZ:   return 0b1011;
      case SNS_12D5HZ:  return 0b0001;
      case SNS_26HZ:    return 0b0010;
      case SNS_52HZ:    return 0b0011;
      case SNS_104HZ:   return 0b0100;
      case SNS_208HZ:   return 0b0101;
      case SNS_416HZ:   return 0b0110;
      case SNS_833HZ:   return 0b0111;
      case SNS_1666HZ:  return 0b1000;
      case SNS_3333HZ:  return 0b1001;
      case SNS_6666HZ:  return 0b1010;
      case 0:           return 0;       /* off */
    }
  }


  /*
   * convert period to an odr value - GY
   */
  uint8_t period2odr_gy(uint32_t period) {
    switch(period) {
      default:
        call Panic.panic(PANIC_SNS, 17, period, 0, 0, 0);
        return 0;
      case SNS_12D5HZ:  return 0b0001;
      case SNS_26HZ:    return 0b0010;
      case SNS_52HZ:    return 0b0011;
      case SNS_104HZ:   return 0b0100;
      case SNS_208HZ:   return 0b0101;
      case SNS_416HZ:   return 0b0110;
      case SNS_833HZ:   return 0b0111;
      case SNS_1666HZ:  return 0b1000;
      case SNS_3333HZ:  return 0b1001;
      case SNS_6666HZ:  return 0b1010;
      case 0:           return 0;       /* off */
    }
  }


  /*
   * convert period to an odr value - MAG
   */
  uint8_t period2odr_mag(uint32_t period) {
    switch(period) {
      default:
        call Panic.panic(PANIC_SNS, 18, period, 0, 0, 0);
        return 0;
      case SNS_10HZ:    return 0b00;
      case SNS_20HZ:    return 0b01;
      case SNS_50HZ:    return 0b10;
      case SNS_100HZ:   return 0b11;
      case 0:           return 0;       /* off */
    }
  }


  void set_reg_bank(uint8_t reg_bank) {
    call SpiReg.writeOne(LSM6DSOX_FUNC_CFG_ACCESS, reg_bank);
  }


  uint8_t get_reg_bank() {
    return call SpiReg.readOne(LSM6DSOX_FUNC_CFG_ACCESS);
  }


  void capture_state(uint8_t where) {
#ifdef LSM6_DEBUG
    lsm6state_t *sp;
    uint8_t      prev_regs;

    sp = &lsm6state[lsm6state_idx];
    sp->where = where;
    sp->ts = call Platform.localTime();

    prev_regs = get_reg_bank();
    set_reg_bank(LSM6DSOX_MAIN_REGS);

    sp->fc1   = call SpiReg.readOne(LSM6DSOX_FIFO_CTRL1);
    sp->fc2   = call SpiReg.readOne(LSM6DSOX_FIFO_CTRL2);
    sp->fc3   = call SpiReg.readOne(LSM6DSOX_FIFO_CTRL3);
    sp->fc4   = call SpiReg.readOne(LSM6DSOX_FIFO_CTRL4);
    sp->fs1   = call SpiReg.readOne(LSM6DSOX_FIFO_STATUS1);
    sp->fs2   = call SpiReg.readOne(LSM6DSOX_FIFO_STATUS2);
    sp->int1c = call SpiReg.readOne(LSM6DSOX_INT1_CTRL);
    sp->c1_xl = call SpiReg.readOne(LSM6DSOX_CTRL1_XL);
    sp->c2_gy = call SpiReg.readOne(LSM6DSOX_CTRL2_G);
    sp->c3_c  = call SpiReg.readOne(LSM6DSOX_CTRL3_C);
    sp->c4_c  = call SpiReg.readOne(LSM6DSOX_CTRL4_C);
    sp->c6_c  = call SpiReg.readOne(LSM6DSOX_CTRL6_C);
    sp->c9_xl = call SpiReg.readOne(LSM6DSOX_CTRL9_XL);

    set_reg_bank(LSM6DSOX_SHUB_REGS);

    sp->master_config = call SpiReg.readOne(LSM6DSOX_MASTER_CONFIG);
    sp->s0_add        = call SpiReg.readOne(LSM6DSOX_SLV0_ADDR);
    sp->s0_reg        = call SpiReg.readOne(LSM6DSOX_SLV0_REG);
    sp->s0_config     = call SpiReg.readOne(LSM6DSOX_SLV0_CONFIG);
    sp->s1_add        = call SpiReg.readOne(LSM6DSOX_SLV1_ADDR);
    sp->s1_reg        = call SpiReg.readOne(LSM6DSOX_SLV1_REG);
    sp->s1_config     = call SpiReg.readOne(LSM6DSOX_SLV1_CONFIG);
    sp->dw_s0         = call SpiReg.readOne(LSM6DSOX_DATAWRITE_SLV0);
    sp->status_master = call SpiReg.readOne(LSM6DSOX_STATUS_MASTER);

    sp->sx_other      = call SpiReg.readOne(LSM6DSOX_SLV2_ADDR);
    sp->sx_other     |= call SpiReg.readOne(LSM6DSOX_SLV2_REG);
    sp->sx_other     |= call SpiReg.readOne(LSM6DSOX_SLV2_CONFIG);
    sp->sx_other     |= call SpiReg.readOne(LSM6DSOX_SLV3_ADDR);
    sp->sx_other     |= call SpiReg.readOne(LSM6DSOX_SLV3_REG);
    sp->sx_other     |= call SpiReg.readOne(LSM6DSOX_SLV3_CONFIG);

    set_reg_bank(LSM6DSOX_MAIN_REGS);

    lsm6state_idx++;
    if (lsm6state_idx >= LSM6_CAP_SIZE)
      lsm6state_idx = 0;
    set_reg_bank(prev_regs);
#endif
  }


  /*
   * read_shdev: read a single byte from a Sensor Hub Device.
   *
   * input:     addr    7 bit i2c addr of device, left shifted 1 bit.
   *            reg     starting register to be read
   *            valp    pointer to 8 bit cell to store data, NULL no store
   *            len     number of registers to read
   *
   * len currently can be 1 (singleton) or 3 (3 register mag state).
   *
   * returns:   SUCCESS no issues
   *            ENOACK  bad address, no such device (NACK seen)
   *            ETIMEOUT operation took too long.
   *
   * Requires both the XL and GY to be shutdown (idle).  Requires Main
   * reg bank to be selected.
   */
  error_t read_shdev(uint8_t addr, uint8_t reg, uint8_t *valp, uint8_t len) {
    lsm6dsox_ctrl1_xl_t      xl_ctrl;
    lsm6dsox_ctrl2_g_t       gy_ctrl;
    lsm6dsox_master_config_t master_config;
    lsm6dsox_status_master_t master_status;
    uint32_t                 t0, t1;
    error_t                  rtn;
    uint8_t                  tmp;

    /* should always start looking at Main Regs */
    tmp = get_reg_bank();
    if (tmp)
      call Panic.panic(PANIC_SNS, 0, tmp, 0, 0, 0);

    xl_ctrl.bits = call SpiReg.readOne(LSM6DSOX_CTRL1_XL);
    gy_ctrl.bits = call SpiReg.readOne(LSM6DSOX_CTRL2_G);
    if (xl_ctrl.x.odr_xl || gy_ctrl.x.odr_g)
      call Panic.panic(PANIC_SNS, 19, xl_ctrl.bits, gy_ctrl.bits, 0, 0);

    set_reg_bank(LSM6DSOX_SHUB_REGS);
    master_config.bits = call SpiReg.readOne(LSM6DSOX_MASTER_CONFIG);
    if (master_config.x.master_on)
      call Panic.panic(PANIC_SNS, 20, master_config.bits, 0, 0, 0);

    call SpiReg.writeOne(LSM6DSOX_SLV0_ADDR,   addr | SHUB_READ);
    call SpiReg.writeOne(LSM6DSOX_SLV0_REG,    reg);
    call SpiReg.writeOne(LSM6DSOX_SLV0_CONFIG, len);      /* len ops */

    /*
     * turn master_on, 1 channel, slv0.
     * start_config is set so we trigger the shub on xl drdy.
     * turn on write_once when reading using slv0.  (required)
     */
    master_config.bits = 0;                             /* 1 channel, slv0 */
    master_config.x.master_on = 1;                      /* read using slv0 */
    master_config.x.write_once = 1;
    SET_SHUB_PU(master_config);
    call SpiReg.writeOne(LSM6DSOX_MASTER_CONFIG, master_config.bits);

    set_reg_bank(LSM6DSOX_MAIN_REGS);
    xl_ctrl.bits = 0;
    xl_ctrl.x.odr_xl = LSM6DSOX_XL_ODR_104Hz;
    call SpiReg.writeOne(LSM6DSOX_CTRL1_XL, xl_ctrl.bits);

    /* look for ENDOP or NACK, on channel 1 */
    rtn = SUCCESS;
    t0 = call Platform.localTime();
    while (TRUE) {
      master_status.bits = call SpiReg.readOne(LSM6DSOX_STATUS_MASTER_MAINPAGE);
      if (master_status.x.slave1_nack || master_status.x.slave2_nack || master_status.x.slave3_nack)
        call Panic.panic(PANIC_SNS, 0xff, master_status.bits, 0, 0, 0);
      if (master_status.x.slave0_nack) {
        rtn = ENOACK;
        break;
      }
      if (master_status.x.endop)
        break;
      t1 = call Platform.localTime();
      if (t1 - t0 > 20) {               /* only spin for 20 ms */
        rtn = ETIMEOUT;
        break;
      }
    }

    set_reg_bank(LSM6DSOX_SHUB_REGS);
    master_config.bits = 0;             /* will turn off master_on */
    SET_SHUB_PU(master_config);
    call SpiReg.writeOne(LSM6DSOX_MASTER_CONFIG, master_config.bits);
    t0 = call Platform.usecsRaw();
    do
      t1 = call Platform.usecsRaw();
    while (t1 - t0 < 330);
    call SpiReg.writeOne(LSM6DSOX_SLV0_CONFIG, 0);
    tmp = LSM6DSOX_SENSOR_HUB_1;
    while (len) {
      if (valp)
        *valp++ = call SpiReg.readOne(tmp++);
      else
        call SpiReg.readOne(tmp++);
      len--;
    }
    set_reg_bank(LSM6DSOX_MAIN_REGS);

    /* shut down XL */
    call SpiReg.writeOne(LSM6DSOX_CTRL1_XL, 0);
    return rtn;
  }


  /*
   * write_shdev: write a single byte to a Sensor Hub Device.
   *
   * input:     addr    7 bit i2c addr of device, left shifted 1 bit.
   *            reg     register to be written
   *            data    datum to be written.
   *
   * returns:   SUCCESS no issues
   *            ENOACK  bad address, no such device (NACK seen)
   *            ETIMEOUT operation took too long.
   *
   * Requires both the XL and GY to be shutdown (idle).
   */
  error_t write_shdev(uint8_t addr, uint8_t reg, uint8_t data) {
    lsm6dsox_ctrl1_xl_t      xl_ctrl;
    lsm6dsox_ctrl2_g_t       gy_ctrl;
    lsm6dsox_master_config_t master_config;
    lsm6dsox_status_master_t master_status;
    uint32_t                 t0, t1;
    error_t                  rtn;
    uint8_t                  data_in;
    bool                     wod_seen;  /* write_once_done seen */

    data_in = get_reg_bank();           /* should be on main regs */
    if (data_in)
      call Panic.panic(PANIC_SNS, 0, data_in, 0, 0, 0);

    xl_ctrl.bits = call SpiReg.readOne(LSM6DSOX_CTRL1_XL);
    gy_ctrl.bits = call SpiReg.readOne(LSM6DSOX_CTRL2_G);
    if (xl_ctrl.x.odr_xl || gy_ctrl.x.odr_g)
      call Panic.panic(PANIC_SNS, 21, xl_ctrl.bits, gy_ctrl.bits, 0, 0);

    set_reg_bank(LSM6DSOX_SHUB_REGS);
    master_config.bits = call SpiReg.readOne(LSM6DSOX_MASTER_CONFIG);
    if (master_config.x.master_on)
      call Panic.panic(PANIC_SNS, 22, master_config.bits, 0, 0, 0);

    call SpiReg.writeOne(LSM6DSOX_SLV0_ADDR,      addr); /* write */
    call SpiReg.writeOne(LSM6DSOX_SLV0_REG,       reg);
    call SpiReg.writeOne(LSM6DSOX_SLV0_CONFIG,    1);    /* 1 op */
    call SpiReg.writeOne(LSM6DSOX_DATAWRITE_SLV0, data);

    /* set up to read it back to verify */
    call SpiReg.writeOne(LSM6DSOX_SLV1_ADDR,      addr | SHUB_READ);
    call SpiReg.writeOne(LSM6DSOX_SLV1_REG,       reg);
    call SpiReg.writeOne(LSM6DSOX_SLV1_CONFIG,    1);    /* 1 op */

    /*
     * turn master_on, 2 sensor, slv0, leave shub_pu_en alone
     * start_config is clear so we trigger the shub on xl drdy.
     */
    master_config.bits         = 1;             /* 2 sensor channels */
    master_config.x.master_on  = 1;
    SET_SHUB_PU(master_config);
    master_config.x.write_once = 1;
    call SpiReg.writeOne(LSM6DSOX_MASTER_CONFIG, master_config.bits);
    set_reg_bank(LSM6DSOX_MAIN_REGS);

    xl_ctrl.bits = 0;
    xl_ctrl.x.odr_xl = LSM6DSOX_XL_ODR_104Hz;
    call SpiReg.writeOne(LSM6DSOX_CTRL1_XL, xl_ctrl.bits);

    /* look for ENDOP or NACK, on channel 1 */
    rtn = SUCCESS;
    t0 = call Platform.localTime();
    wod_seen = FALSE;
    while (TRUE) {
      master_status.bits = call SpiReg.readOne(LSM6DSOX_STATUS_MASTER_MAINPAGE);
      if (master_status.x.wr_once_done)
        wod_seen = TRUE;
      if (master_status.x.slave0_nack || master_status.x.slave1_nack) {
        rtn = ENOACK;
        break;
      }
      if (master_status.x.endop) {
        /* we should always have both endop and wr_once_done */
        if (wod_seen)
          break;
        call Panic.panic(PANIC_SNS, 23, master_status.bits, wod_seen, 0, 0);
        break;
      }
      t1 = call Platform.localTime();
      if (t1 - t0 > 20) {               /* only spin for 20 ms */
        rtn = ETIMEOUT;
        break;
      }
    }

    set_reg_bank(LSM6DSOX_SHUB_REGS);
    master_config.bits = 0;
    SET_SHUB_PU(master_config);
    call SpiReg.writeOne(LSM6DSOX_MASTER_CONFIG, master_config.bits);

    t0 = call Platform.usecsRaw();
    do
      t1 = call Platform.usecsRaw();
    while (t1 - t0 < 330);

    call SpiReg.writeOne(LSM6DSOX_SLV0_CONFIG, 0);
    call SpiReg.writeOne(LSM6DSOX_SLV1_CONFIG, 0);
    if (rtn == SUCCESS) {
      data_in = call SpiReg.readOne(LSM6DSOX_SENSOR_HUB_1);
      if (data_in != data)
        call Panic.panic(PANIC_SNS, 24, data, data_in, 0, 0);
    }
    set_reg_bank(LSM6DSOX_MAIN_REGS);

    /* shut down XL */
    call SpiReg.writeOne(LSM6DSOX_CTRL1_XL, 0);
    return rtn;
  }


  /* protected read_shdev.  checks error return */
  void readP_shdev(uint8_t addr, uint8_t reg, uint8_t *valp, uint8_t len) {
    error_t err;

    err = read_shdev(addr, reg, valp, len);
    if (err)
      call Panic.panic(PANIC_SNS, 25, err, 0, 0, 0);
  }


  /* protected write_shdev.  checks error return */
  void writeP_shdev(uint8_t addr, uint8_t reg, uint8_t data) {
    error_t err;

    err = write_shdev(addr, reg, data);
    if (err)
      call Panic.panic(PANIC_SNS, 26, err, 0, 0, 0);
  }


  /* reset_lsm6i2c_master: reset the lsm6's master i2c controller */
  void reset_lsm6i2c_master() {
    lsm6dsox_master_config_t master_config;

    set_reg_bank(LSM6DSOX_SHUB_REGS);
    master_config.bits = 0;
    SET_SHUB_PU(master_config);
    master_config.x.rst_master_regs = 1;
    call SpiReg.writeOne(LSM6DSOX_MASTER_CONFIG, master_config.bits);

    /* do we need a delay in here? */

    master_config.x.rst_master_regs = 0;
    call SpiReg.writeOne(LSM6DSOX_MASTER_CONFIG, master_config.bits);
    set_reg_bank(LSM6DSOX_MAIN_REGS);
  }


  void shutdown_mag() {
    writeP_shdev(LIS2MDL_ADDR, LIS2MDL_CFG_REG_A,  LIS2MDL_POWER_DOWN);

    /* clear any potential pending DRDY */
    readP_shdev( LIS2MDL_ADDR, LIS2MDL_OUTX_L_REG, NULL, 6);
    readP_shdev( LIS2MDL_ADDR, LIS2MDL_CFG_REG_A,  last_mag_config, 3);
    readP_shdev( LIS2MDL_ADDR, LIS2MDL_STATUS_REG, &last_mag_status, 1);
  };


  /* initialize the complex sensor array */
  command error_t LSM6Init.init() {
    uint8_t tmp;

    nop();
    nop();

    /*
     * o turn off interrupts.
     * o stop the accel, gyro, and mag
     * o set up interrupts
     * o set up static configuration
     */

    atomic {
      /* disable interrupt, clear any pending */
      call LSM6Int1.disableInterrupt();
      call LSM6Int1.clearInterrupt();
    }

    set_reg_bank(LSM6DSOX_MAIN_REGS);

    /* check for proper chip id */
    tmp = call SpiReg.readOne(LSM6DSOX_WHO_AM_I);
    if (tmp != LSM6DSOX_WHO_I_AM)
      call Panic.panic(PANIC_SNS, 27, tmp, 0, 0, 0);

    reset_lsm6i2c_master();                             /* kick lsm6 i2c, pristine */

    /* make sure fifo is off */
    call SpiReg.writeOne(LSM6DSOX_FIFO_CTRL3, 0);       /* nuke BDR_GY and BDR_XL   */
    call SpiReg.writeOne(LSM6DSOX_FIFO_CTRL4, 0);       /* nuke fifo mode, turn off */

    /* turn off gyro and accel */
    call SpiReg.writeOne(LSM6DSOX_CTRL1_XL, 0);
    call SpiReg.writeOne(LSM6DSOX_CTRL2_G,  0);

    /* set BDU and IF_INC */
    call SpiReg.writeOne(LSM6DSOX_CTRL3_C,  0x44);

    /* set DRDY_MASK (let filters settle) */
    call SpiReg.writeOne(LSM6DSOX_CTRL4_C,  0x08);

    /* Accel High Perf Mode disabled. */
    call SpiReg.writeOne(LSM6DSOX_CTRL6_C,  0x90);

    /* Gyro High Perf Mode disabled. */
    call SpiReg.writeOne(LSM6DSOX_CTRL7_G,  0x80);

    /* leave DEN values alone and i3c_disable */
    call SpiReg.writeOne(LSM6DSOX_CTRL9_XL,  0xE2);

    /* Int1 , FIFO_OVR and FIFO_TH (wtm) */
    call SpiReg.writeOne(LSM6DSOX_INT1_CTRL, 0x18);

    /* talk to the MAG, lis2mdl, verify ID */
    readP_shdev(LIS2MDL_ADDR, LIS2MDL_WHO_AM_I, &tmp, 1);
    if (tmp != LIS2MDL_ID)
      call Panic.panic(PANIC_SNS, 28, tmp, 0, 0, 0);

    /* make sure mag is off, set BDU and DRDY_ON_PIN (drdy goes to Int1) */
    writeP_shdev(LIS2MDL_ADDR, LIS2MDL_CFG_REG_C, 0x11);
    shutdown_mag();

    return SUCCESS;
  }


  command void LSM6.setConfig(uint8_t lsm6_sensor, sensor_config_t *cfg) {
    sensor_config_t *p;

    switch (lsm6_sensor) {
      default:
        call Panic.panic(PANIC_SNS, 29, lsm6_sensor, (parg_t) cfg, 0, 0);
      case LSM6DSOX_GYRO:       p = &gyro_config;  break;
      case LSM6DSOX_ACCEL:      p = &accel_config; break;
      case LSM6DSOX_MAG:        p = &mag_config;   break;
    }
    p->period    = cfg->period;
    p->fs        = cfg->fs;
    p->filter    = cfg->filter;
    p->sensor_id = cfg->sensor_id;
  }


  command void LSM6.setMax(uint16_t maxlen) {
    /* lsm6 has a max depth of 512 entries (7 bytes per) */
    if (maxlen > 511*7)
      maxlen = 511*7;
    maxdata = maxlen;
  }


  command void LSM6.start() {
    uint8_t                  xl_odr, gy_odr;
    uint16_t                 fifo_len;
    uint32_t                 xl_period, gy_period, mag_period;
    lsm6dsox_ctrl1_xl_t      xl_ctrl;
    lsm6dsox_ctrl2_g_t       gy_ctrl;
    lsm6dsox_slv_config_t    slv_config;
    lsm6dsox_master_config_t master_config;
    lsm6dsox_fifo_ctrl2_t    fc2;
    lsm6dsox_fifo_ctrl3_t    fc3;
    lis2mdl_cfg_reg_a_t      cfg_a;

    /*
     * check XL/GY off
     *
     * write_shub(...), checks for master off
     * set mag cfg_a comp_temp_en | LP | odr | md (cont)
     * set mag cfg_b lpf (filter)
     *
     * shub
     * SLV0_ADDR     = MAG_ADDR | READ
     * SLV0_REG      = 68 (mag outx_l_reg)
     * SLV0_CONFIG   = SHUB_ODR | BATCH_EN | numops
     *                  XL/GY        1          6
     *                 just use 104Hz let XL/GY odr dominate
     * master_config = WO | SC | PU_EN | master_on | 1 sensor
     * main
     *
     * FIFO_CTRL1/2, set wtm, odrchg_en
     * FIFO_CTRL3,   set BDR_GY, BDR_XL
     *
     * ctrl4_c,  gyro filter
     * ctrl6_c,  gyro filter
     * ctrl7_g,  gyro filter
     * ctrl8_xl, xl   filter
     *
     * FIFO_CTRL4,   set fifo_mode (cont, 6)
     * ctrl1_xl (odr_xl, fs_xl, filter)
     * ctrl2_g  (odr_gy, fs_gy, filter)
     *
     * turn on interrupts.
     */

    /* should always start looking at Main Regs */
    xl_odr = get_reg_bank();
    if (xl_odr)
      call Panic.panic(PANIC_SNS, 0, xl_odr, 0, 0, 0);

    /* check XL/GY off */
    xl_ctrl.bits = call SpiReg.readOne(LSM6DSOX_CTRL1_XL);
    gy_ctrl.bits = call SpiReg.readOne(LSM6DSOX_CTRL2_G);
    if (xl_ctrl.x.odr_xl || gy_ctrl.x.odr_g)
      call Panic.panic(PANIC_SNS, 21, xl_ctrl.bits, gy_ctrl.bits, 0, 0);

    xl_period  = accel_config.period;
    gy_period  = gyro_config.period;
    mag_period = mag_config.period;
    if (!xl_period && !gy_period) {
      if (!mag_period)
        return;
      call Panic.warn(PANIC_SNS, 0, mag_period, 0, 0, 0);
    }

    /*
     * set the mag up
     * writeP_shdev also checks for master off.
     *
     * this starts the mag up but we won't collect any data until
     * the fifo actually fires up.  Soon grasshopper.
     */
    cfg_a.bits = 0;
    if (mag_period) {
      cfg_a.x.md  = LIS2MDL_CONTINUOUS_MODE;
      cfg_a.x.odr = period2odr_mag(mag_period);
      cfg_a.x.lp  = 1;
      cfg_a.x.comp_temp_en = 1;
    } else
      cfg_a.x.md = LIS2MDL_POWER_DOWN;

    writeP_shdev(LIS2MDL_ADDR, LIS2MDL_CFG_REG_A, cfg_a.bits);
//    readP_shdev( LIS2MDL_ADDR, LIS2MDL_CFG_REG_A, last_mag_config, 3);
//    readP_shdev( LIS2MDL_ADDR, LIS2MDL_STATUS_REG, &last_mag_status, 1);

    /*
     * after writeP/readP_shdev:
     * o master off
     * o SLV0/1_Config zeroed (disabled).
     *
     * if the shub is shutdown do we want to drop the i2c pull ups?
     */

    if (mag_period) {
      /* turn on shub if mag enabled. */
      set_reg_bank(LSM6DSOX_SHUB_REGS);

#ifdef notdef
      master_config.bits = 0;
      SET_SHUB_PU(master_config);
      master_config.x.rst_master_regs = 1;
      call SpiReg.writeOne(LSM6DSOX_MASTER_CONFIG, master_config.bits);
      master_config.x.rst_master_regs = 0;
      call SpiReg.writeOne(LSM6DSOX_MASTER_CONFIG, master_config.bits);
#endif

      slv_config.bits = 0;
      slv_config.x.numop = 6;                   /* 6 byte blocks */
      slv_config.x.batch_ext_sens_en = 1;       /* send to fifo  */
      call SpiReg.writeOne(LSM6DSOX_SLV0_ADDR,   LIS2MDL_ADDR | SHUB_READ);
      call SpiReg.writeOne(LSM6DSOX_SLV0_REG,    LIS2MDL_OUTX_L_REG);
      call SpiReg.writeOne(LSM6DSOX_SLV0_CONFIG, slv_config.bits);

      master_config.bits           = 0;         /* 1 sensor */
      master_config.x.write_once   = 1;
      master_config.x.start_config = 1;         /* trig Shub on DRDY (int2) */
      master_config.x.master_on    = 1;
      SET_SHUB_PU(master_config);
      call SpiReg.writeOne(LSM6DSOX_MASTER_CONFIG, master_config.bits);
      set_reg_bank(LSM6DSOX_MAIN_REGS);
    }

    /* compute where we want WTM, maxdata/7 */
    fifo_len = maxdata / LSM6DSOX_FIFO_ELM_SIZE;
    call SpiReg.writeOne(LSM6DSOX_FIFO_CTRL1, fifo_len & 0xff);
    fc2.bits = 0;
    fc2.x.wtm_b8 = (fifo_len >> 8) & 1;
    fc2.x.odrchg_en = 1;
    call SpiReg.writeOne(LSM6DSOX_FIFO_CTRL2, fc2.bits);

    xl_odr  = period2odr_xl(accel_config.period);
    gy_odr  = period2odr_gy(gyro_config.period);

    fc3.bits = 0;
    fc3.x.bdr_xl = xl_odr;
    fc3.x.bdr_gy = gy_odr;
    call SpiReg.writeOne(LSM6DSOX_FIFO_CTRL3, fc3.bits);

    /* set up any filters, here */

    /* turn fifo on */
    call SpiReg.writeOne(LSM6DSOX_FIFO_CTRL4, LSM6DSOX_FM_STREAM);      /* continuous */

    /* XL: odr and filter stuff */
    xl_ctrl.bits = 0;
    xl_ctrl.x.odr_xl = xl_odr;
    call SpiReg.writeOne(LSM6DSOX_CTRL1_XL, xl_ctrl.bits);

    /* GY: odr and filter stuff */
    gy_ctrl.bits = 0;
    gy_ctrl.x.odr_g = gy_odr;
    call SpiReg.writeOne(LSM6DSOX_CTRL2_G, gy_ctrl.bits);

    /*
     * check for strange configurations and bitch
     *
     * 1) running start with nothing turned on
     * 2) mag turned on but both XL and GY are off
     */
    if (!xl_odr && !gy_odr && !mag_period)
      call Panic.warn(PANIC_SNS, 1, 0, 0, 0, 0);
    if (!xl_odr && !gy_odr && mag_period)
      call Panic.warn(PANIC_SNS, 2, 0, 0, 0, 0);

    call LSM6Int1.enableInterrupt();
  }


  command void LSM6.stop(bool drain) {
    lsm6dsox_master_config_t master_config;
    uint8_t  tmp;
    uint32_t t0, t1;

    call LSM6Int1.disableInterrupt();
    tmp = get_reg_bank();
    if (tmp)
      call Panic.panic(PANIC_SNS, 0, tmp, 0, 0, 0);

    /*
     * shutdown master
     *
     * manuals say we need a 300us wait when turning off I2C SHUB or
     * mucking about with XL/GY configuration.
     */
    set_reg_bank(LSM6DSOX_SHUB_REGS);
    master_config.bits = 0;
    SET_SHUB_PU(master_config);
    call SpiReg.writeOne(LSM6DSOX_MASTER_CONFIG, master_config.bits);

    t0 = call Platform.usecsRaw();
    do
      t1 = call Platform.usecsRaw();
    while (t1 - t0 < 330);

    call SpiReg.writeOne(LSM6DSOX_SLV0_CONFIG, 0);
    call SpiReg.writeOne(LSM6DSOX_SLV1_CONFIG, 0);
    set_reg_bank(LSM6DSOX_MAIN_REGS);

    /* shutdown XL and GY, then talk to the MAG */
    call SpiReg.writeOne(LSM6DSOX_CTRL1_XL, 0);
    call SpiReg.writeOne(LSM6DSOX_CTRL2_G,  0);

    /* turn off mag */
    shutdown_mag();

    /* drain fifo, if requested.  upper will request actual. */
    if (drain)
      signal LSM6.dataAvail();

    /* turn off and reset FIFO */
    call SpiReg.writeOne(LSM6DSOX_FIFO_CTRL4, 0);
  }


  command uint16_t LSM6.bytesAvail() {
    lsm6dsox_fifo_status2_t  fs2;
    uint16_t avail;
    uint8_t  tmp;

    /* must read FIFO_STATUS1 first (BDU). */
    tmp = call SpiReg.readOne(LSM6DSOX_FIFO_STATUS1);
    fs2.bits = call SpiReg.readOne(LSM6DSOX_FIFO_STATUS2);
    avail    = fs2.x.diff_fifo_upper << 8 | tmp;
    avail   *= LSM6DSOX_FIFO_ELM_SIZE;
    return avail;
  };


  command void LSM6.read(uint8_t *buf, uint16_t len) {
    nop();
    nop();
    if (((len / LSM6DSOX_FIFO_ELM_SIZE) * LSM6DSOX_FIFO_ELM_SIZE) != len)
      call Panic.panic(PANIC_SNS, 30, len, 0, 0, 0);
    call SpiReg.readMultiple(LSM6DSOX_FIFO_DATA_OUT_TAG, buf, len);
  }


  command uint8_t LSM6.getReg(uint8_t reg) {
    return call SpiReg.readOne(reg);
  }


  command void LSM6.setReg(uint8_t reg, uint8_t val) {
    call SpiReg.writeOne(reg, val);
  }


  task void lsm6int1_task() {
    signal LSM6.dataAvail();
  }


  async event void LSM6Int1.interrupt() {
    /* clear interrupt? */
    nop();
    nop();
    post lsm6int1_task();
  }

  async event void Panic.hook()         { }
}
