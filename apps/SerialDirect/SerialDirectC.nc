// $Id$

/**
 *  @author Eric B. Decker
 *  @date   Mar 6 2010
 **/

#include "msp430usci.h"

const msp430_uart_union_config_t uart_config = { {
  ubr:		UBR_8MHZ_4800,
  umctl:	UMCTL_8MHZ_4800,
  ucmode:	0,			// uart
  ucspb:	0,			// one stop
  uc7bit:	0,			// 8 bit
  ucpar:	0,			// odd parity (but no parity)
  ucpen:	0,			// parity disabled
  ucrxeie:	0,			// err int off
  ucssel:	2,			// smclk
  utxe:		1,			// enable tx
  urxe:		1,			// enable rx
} };

uint16_t rx_ints, tx_ints;

module SerialDirectC {
  uses {
    interface HplMsp430UsciA as Port;
    interface HplMsp430UsciInterrupts as PortInt;
    interface Boot;
  }
}
implementation {
  event void Boot.booted() {
    call Port.setModeUart((msp430_uart_union_config_t *) &uart_config);
    while(1) {
      if (call Port.isTxIntrPending())
	call Port.tx(0x55);
    }
  }

  async event void PortInt.txDone() {
    tx_ints++;
  }

  async event void PortInt.rxDone(uint8_t data) {
    uint8_t tmp;

    rx_ints++;
    tmp = call Port.rx();
  }
}
