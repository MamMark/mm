
module Lis3dhP {
  provides interface Lis3dh;
  uses     interface SpiReg;
}
implementation {

#include "lis3dh.h"

  command uint8_t Lis3dh.whoAmI() {
    uint8_t id;

    nop();
    call SpiReg.read(WHO_AM_I, &id, 1);
    return id;
  }


  /*
   * Experiment with setting up the chip to sample at 1Hz
   */
  command void Lis3dh.config1Hz() {
    uint8_t val;

    nop();
    /* set High Resolution (HR) */
    val = HR;
    call SpiReg.write(CTRL_REG4, &val, 1);
    val = (ODR_1HZ | ZEN | YEN | XEN);
    call SpiReg.write(CTRL_REG1, &val, 1);
  }

  command bool Lis3dh.xyzDataAvail() {
    uint8_t status;

    nop();
    call SpiReg.read(STATUS_REG, &status, 1);
    return status & XYZDA;
  }


  command void Lis3dh.readSample(uint8_t *buf, uint8_t bufLen) {
    nop();
    call SpiReg.read_multiple(OUT_X_L, buf, bufLen);
  }
}
