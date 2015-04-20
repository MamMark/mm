/**
 *
 * Copyright 2010 (c) Eric Decker
 * All rights reserved.
 *
 * @author Eric Decker
 * @date Feb 25, 2010
 */

#ifndef _H_PLATFORM_SERIAL_DOCK_H
#define _H_PLATFORM_SERIAL_DOCK_H

#include "msp430usart.h"

/*
 * MM3, 1611, uses lots of control bits
 */

const msp430_uart_union_config_t dock_serial_config = { {

//       ubr:   UBR_4MHZ_57600,
//       umctl: UMCTL_4MHZ_57600,

  ubr:   UBR_4MHZ_115200,
  umctl: UMCTL_4MHZ_115200,
  ssel: 0x02,		// smclk selected (DCO, 4MHz)
  pena: 0,		// no parity
  pev: 0,		// no parity
  spb: 0,		// one stop bit
  clen: 1,		// 8 bit data
  listen: 0,		// no loopback
  mm: 0,		// idle-line
  ckpl: 0,		// non-inverted clock
  urxse: 0,		// start edge off
  urxeie: 1,		// error interrupt enabled
  urxwie: 0,		// rx wake up disabled
  utxe : 1,		// tx interrupt enabled
  urxe : 1		// rx interrupt enabled
  } };

#endif	/* _H_PLATFORM_SERIAL_DOCK_H */
