/**
 *
 * Copyright 2008-2010 (c) Eric B. Decker
 * All rights reserved.
 *
 * @author Eric B. Decker
 */

#include "serial_speed.h"

module mm3SerialP {
  provides {
    interface StdControl;
    interface Msp430UartConfigure;
  }
  uses {
    interface HplMsp430Usart as Usart;
  }
}
implementation {
  
#if defined(MM_MM3)

  msp430_uart_union_config_t mm3_direct_serial_config = {
    {
//       ubr:   UBR_4MHZ_57600,
//       umctl: UMCTL_4MHZ_57600,
      ubr:   UBR_4MHZ_115200,
      umctl: UMCTL_4MHZ_115200,
       ssel: 0x02,		// smclk selected (DCO, 4MHz)
       pena: 0,			// no parity
       pev: 0,			// no parity
       spb: 0,			// one stop bit
       clen: 1,			// 8 bit data
       listen: 0,		// no loopback
       mm: 0,			// idle-line
       ckpl: 0,			// non-inverted clock
       urxse: 0,		// start edge off
       urxeie: 1,		// error interrupt enabled
       urxwie: 0,		// rx wake up disabled
       utxe : 1,		// tx interrupt enabled
       urxe : 1			// rx interrupt enabled
    }
  };

#elif defined(MM_MM4)

  msp430_uart_union_config_t mm3_direct_serial_config = {
    {
//       ubr:   UBR_4MHZ_57600,
//       umctl: UMCTL_4MHZ_57600
      ubr:   UBR_4MHZ_115200,
      umctl: UMCTL_4MHZ_115200
    }
  };

#else
#error need one of MM_MM3, MM_MM4, MM_MM5 defined.
#endif


  command error_t StdControl.start(){
    return SUCCESS;
  }

  command error_t StdControl.stop(){
    return SUCCESS;
  }

  async command msp430_uart_union_config_t* Msp430UartConfigure.getConfig() {
    mmP5out.ser_sel = SER_SEL_CRADLE;
    return &mm3_direct_serial_config;
  }
}
