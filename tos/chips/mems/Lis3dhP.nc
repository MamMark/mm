module Lis3dhP {
  provides interface Init;
  provides interface Lis3dh;

  uses interface Resource as SpiResource;
  //uses interface SpiBlock as SpiBlock;
  uses interface SpiByte as SpiByte;

  uses interface HplMsp430GeneralIO as CS;

  //provides interface Msp430UsciConfigure;
}

#include "lis3dh.h"

implementation {
  command error_t Init.init() {
    call CS.set();
    call CS.makeOutput();
    return SUCCESS;
  }

  command error_t Lis3dh.whoAmI() {
    return call SpiResource.request();
  }

  event void SpiResource.granted() {
    uint8_t id;
    if (call SpiResource.isOwner()) {
      call CS.clr();
      id = call SpiByte.write(DIR_READ | WHO_AM_I);
      call CS.set();
      signal Lis3dh.whoAmIDone(SUCCESS, id);
    }
  }
}
