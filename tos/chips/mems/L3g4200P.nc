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
}
