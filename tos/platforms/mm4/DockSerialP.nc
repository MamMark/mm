/**
 *
 * Copyright 2008-2010 (c) Eric B. Decker
 * All rights reserved.
 *
 * @author Eric B. Decker
 */

#include "platform_dock_serial.h"

module DockSerialP {
  provides {
    interface StdControl;
    interface Msp430UartConfigure;
  }
  uses interface Resource;
}
implementation {
  command error_t StdControl.start() {
    return call Resource.immediateRequest();
  }

  command error_t StdControl.stop() {
    call Resource.release();
    SER_SEL = SER_SEL_NONE;
    return SUCCESS;
  }

  async command msp430_uart_union_config_t* Msp430UartConfigure.getConfig() {
    SER_SEL = SER_SEL_DOCK;
    return (msp430_uart_union_config_t *) &dock_serial_config;
  }

  event void Resource.granted() { }

}
