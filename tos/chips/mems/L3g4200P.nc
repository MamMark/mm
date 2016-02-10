module L3g4200P {
  provides interface Init;
  provides interface L3g4200;

  uses interface Resource as SpiResource;
  //uses interface SpiBlock as SpiBlock;
  uses interface SpiByte as SpiByte;

  uses interface HplMsp430GeneralIO as CS;

  //provides interface Msp430UsciConfigure;
}

#include "l3g4200.h"

implementation {
  command error_t Init.init() {
    call CS.set();
    call CS.makeOutput();
    return SUCCESS;
  }

  command error_t L3g4200.whoAmI() {
    return call SpiResource.request();
  }

  event void SpiResource.granted() {
    uint8_t id;
    if (call SpiResource.isOwner()) {
      call CS.clr();
      id = call SpiByte.write(DIR_READ | WHO_AM_I);
      call CS.set();
      signal L3g4200.whoAmIDone(SUCCESS, id);
    }
  }
}
