/**
 *
 * Copyright 2010 (c) Eric Decker
 * All rights reserved.
 *
 * @author Eric Decker
 */

#ifndef _H_PLATFORM_SIRF3_SERIAL_H_
#define _H_PLATFORM_SIRF3_SERIAL_H_

#include "msp430usci.h"

/*
 * MM4, 2618, USCI
 */

const msp430_uart_union_config_t sirf3_4800_serial_config = { {
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


const msp430_uart_union_config_t sirf3_57600_serial_config = { {
  ubr:		UBR_8MHZ_57600,
  umctl:	UMCTL_8MHZ_57600,
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


#endif	/* _H_PLATFORM_SIRF3_SERIAL_H_ */
