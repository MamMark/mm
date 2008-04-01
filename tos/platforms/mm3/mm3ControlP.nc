/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

module mm3ControlP {
  provides {
    interface mm3Control;
    interface Init;
  }
  uses {
    interface Panic;
  }
}

implementation {

  command bool mm3Control.eavesdrop(uint8_t sns_id) {
    return TRUE;
  }

  command error_t Init.init() {
    return SUCCESS;
  }
}
