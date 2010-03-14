/**
 *
 * Copyright 2010 (c) Eric Decker
 * All rights reserved.
 *
 * @author Eric Decker
 * @date Feb 25, 2010
 */

#ifndef _H_PLATFORM_DOCK_SERIAL_H
#define _H_PLATFORM_DOCK_SERIAL_H

#include "msp430usci.h"

/*
 * MM4, 2618, UCSI, Assigned to USCI A1, uart.
 */

const msp430_uart_union_config_t dock_serial_config = { {

//       ubr:   UBR_8MHZ_57600,
//       umctl: UMCTL_8MHZ_57600,

  ubr:   UBR_8MHZ_115200,
  umctl: UMCTL_8MHZ_115200,
  ucmode:	0,			// uart
  ucspb:	0,			// one stop
  uc7bit:	0,			// 8 bit
  ucpar:	0,			// odd parity (but no parity)
  ucpen:	0,			// parity disabled
  ucrxeie:	0,			// err int off
  ucssel:	0x02,			// smclk
  utxe:		1,			// enable tx
  urxe:		1,			// enable rx
  } };

#endif	/* _H_PLATFORM_DOCK_SERIAL_H */
