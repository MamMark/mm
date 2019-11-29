
module LisXdhP {
  provides interface LisXdh;
  uses     interface SpiReg;
}
implementation {

#include "lisxdh.h"

  command uint8_t LisXdh.whoAmI() {
    uint8_t id;

    nop();
    call SpiReg.read(WHO_AM_I, &id, 1);
    return id;
  }


  /*
   * Experiment with setting up the chip to sample at 1Hz
   */
  command void LisXdh.config1Hz() {
    uint8_t val;

    nop();
    /* set High Resolution (HR) */
    val = HR;
    call SpiReg.write(CTRL_REG4, &val, 1);
    val = (ODR_1HZ | ZEN | YEN | XEN);
    call SpiReg.write(CTRL_REG1, &val, 1);
  }

  command bool LisXdh.xyzDataAvail() {
    uint8_t status;

    nop();
    call SpiReg.read(STATUS_REG, &status, 1);
    return status & XYZDA;
  }


  command void LisXdh.readSample(uint8_t *buf, uint8_t bufLen) {
    nop();
    call SpiReg.read_multiple(OUT_X_L, buf, bufLen);
  }
}
