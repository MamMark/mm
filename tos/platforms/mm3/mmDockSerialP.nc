/**
 *
 * Copyright 2008-2010 (c) Eric B. Decker
 * All rights reserved.
 *
 * @author Eric B. Decker
 */

#include "platform_dock_serial.h"

module mmDockSerialP {
  provides {
    interface StdControl;
    interface Msp430UartConfigure;
  }
}
implementation {
  
  command error_t StdControl.start(){
    return SUCCESS;
  }

  command error_t StdControl.stop(){
    return SUCCESS;
  }

  async command msp430_uart_union_config_t* Msp430UartConfigure.getConfig() {
    SER_SEL = SER_SEL_CRADLE;
    return (msp430_uart_union_config_t *) &dock_serial_config;
  }
}
