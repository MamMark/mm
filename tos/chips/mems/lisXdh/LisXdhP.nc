
module LisXdhP {
  provides interface LisXdh;
  uses     interface SpiReg;
}
implementation {

#include "lisxdh.h"

  command uint8_t LisXdh.whoAmI() {
    uint8_t id;

    nop();
    call SpiReg.read(LISX_WHO_AM_I, &id, 1);
    return id;
  }


  /*
   * Experiment with setting up the chip to sample at 1Hz
   */
  command void LisXdh.config1Hz() {
    lisx_ctrl_reg1_t val1;
    lisx_ctrl_reg4_t val4;

    nop();
    /* set High Resolution (HR) */
    val4.hr = 1;
    call SpiReg.write(LISX_CTRL_REG4, (void *) &val4, 1);
    val1.odr = ODR_10HZ;
    val1.zen = 1;
    val1.yen = 1;
    val1.xen = 1;
    call SpiReg.write(LISX_CTRL_REG1, (void *) &val1, 1);
  }

  command bool LisXdh.xyzDataAvail() {
    lisx_status_reg_t status;

    nop();
    call SpiReg.read(LISX_STATUS_REG, (void *) &status, 1);
    return status.zyxda;
  }


  command void LisXdh.readSample(uint8_t *buf, uint8_t bufLen) {
    nop();
    call SpiReg.read_multiple(OUT_X_L, buf, bufLen);
  }
}
