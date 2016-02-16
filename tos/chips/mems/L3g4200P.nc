module L3g4200P {
  provides {
    interface L3g4200;
  }

  uses {
    interface MemsCtrl;
  }
}

#include "l3g4200.h"

implementation {
  command error_t L3g4200.whoAmI(uint8_t *id) {
    nop();
    nop();
    nop();
    return call MemsCtrl.readReg(WHO_AM_I, id);
  }

  command error_t L3g4200.config100Hz() {
    error_t ret;

    nop();
    nop();
    nop();

    /* Turn on chip and set output data rate */
    /* For now, just turn on power and enable xyz
     * Setting DR:BW to zero gives the lowest output rate (100Hz)
     */
    ret = call MemsCtrl.writeReg(CTRL_REG1, (POWER | ZEN | YEN | XEN));
    if (ret != SUCCESS)
      return ret;

    return SUCCESS;
  }

  command bool L3g4200.xyzDataAvail() {
    uint8_t status;

    nop();
    nop();
    nop();

    if (call MemsCtrl.readReg(STATUS_REG, &status) != SUCCESS)
      return FALSE;

    return status & ZYXDA;
  }

  command error_t L3g4200.readSample(uint8_t *buf, uint8_t bufLen) {
    nop();
    nop();
    nop();

    return call MemsCtrl.spiRx(OUT_X_L, buf, bufLen, TRUE);
  }
}
