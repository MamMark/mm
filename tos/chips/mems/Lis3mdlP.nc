module Lis3mdlP {
  provides {
    interface Lis3mdl;
  }

  uses {
    interface MemsCtrl;
  }
}

#include "lis3mdl.h"

implementation {
  command error_t Lis3mdl.whoAmI(uint8_t *id) {
    nop();
    nop();
    nop();
    return call MemsCtrl.readReg(WHO_AM_I, id);
  }

  command error_t Lis3mdl.config10Hz() {
    error_t ret;

    nop();
    nop();
    nop();

    /* Set perf mode and output data rate */
    ret = call MemsCtrl.writeReg(CTRL_REG1, (OP_HIGH_PERF | ODR_10_HZ));
    if (ret != SUCCESS)
      return ret;

    /* Set Full Scale to +- 8 Gauss */
    ret = call MemsCtrl.writeReg(CTRL_REG2, FS_8G);
    if (ret != SUCCESS)
      return ret;

    /* Default mode is power down, switch this to continuous conversion */
    ret = call MemsCtrl.writeReg(CTRL_REG3, CONV_CONT);
    if (ret != SUCCESS)
      return ret;

    /* Set mode for z axis */
    ret = call MemsCtrl.writeReg(CTRL_REG4, OMZ_HIGH_PERF);
    if (ret != SUCCESS)
      return ret;

    return SUCCESS;
  }

  command bool Lis3mdl.xyzDataAvail() {
    uint8_t status;

    nop();
    nop();
    nop();

    if (call MemsCtrl.readReg(STATUS_REG, &status) != SUCCESS)
      return FALSE;

    return status & ZYXDA;
  }

  command error_t Lis3mdl.readSample(uint8_t *buf, uint8_t bufLen) {
    nop();
    nop();
    nop();

    return call MemsCtrl.spiRx(OUT_X_L, buf, bufLen, TRUE);
  }
}
