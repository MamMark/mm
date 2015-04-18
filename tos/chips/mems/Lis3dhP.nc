module Lis3dhP {
  provides {
    interface Lis3dh;
  }

  uses  {
    interface MemsCtrl;
  }
}

#include "lis3dh.h"

implementation {
  command error_t Lis3dh.whoAmI(uint8_t *id) {
    nop();
    nop();
    nop();
    return call MemsCtrl.readReg(WHO_AM_I, id);
  }

  /*
   * Experiment with setting up the chip to sample at 1Hz
   */
  command error_t Lis3dh.config1Hz() {
    error_t ret;

    nop();
    nop();
    nop();
    /* Turn on chip and set output data rate */
    ret = call MemsCtrl.writeReg(CTRL_REG4, HR);
    if (ret != SUCCESS)
      return ret;

    ret = call MemsCtrl.writeReg(CTRL_REG1, ODR_1HZ | ZEN | YEN | XEN);
    if (ret != SUCCESS)
      return ret;

    /* Enable FIFO so we don't have to sample as frequently */
    ret = call MemsCtrl.writeReg(CTRL_REG5, FIFO_EN);
    if (ret != SUCCESS)
      return ret;

    ret = call MemsCtrl.writeReg(FIFO_CTRL_REG, FIFO_MODE);
    if (ret != SUCCESS)
      return ret;

    return SUCCESS;
  }

  command bool Lis3dh.xyzDataAvail() {
    uint8_t status;
    
    nop();
    nop();
    nop();
    if (call MemsCtrl.readReg(STATUS_REG, &status) != SUCCESS)
      return FALSE;

    return status & XYZDA;
  }

  command error_t Lis3dh.readSample(uint8_t *buf, uint8_t bufLen) {
    nop();
    nop();
    nop();
    return call MemsCtrl.spiRx(OUT_X_L, buf, bufLen, TRUE);
  }
}
