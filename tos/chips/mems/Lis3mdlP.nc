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
}
