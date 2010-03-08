/**
 *
 * Copyright 2010 (c) Eric Decker
 * All rights reserved.
 *
 * @author Eric Decker
 */

#ifndef _H_MM3SIRF3_DEFS_H
#define _H_MM3SIRF3_DEFS_H

#include "msp430usart.h"

/*
 * MM3, 1611, uses lots of control bits
 */

const msp430_uart_union_config_t sirf3_4800_serial_config = { {
  ubr:   UBR_4MHZ_4800,
  umctl: UMCTL_4MHZ_4800,
  ssel: 0x02,			// smclk selected (DCO, 4MHz)
  pena: 0,			// no parity
  pev: 0,			// no parity
  spb: 0,			// one stop bit
  clen: 1,			// 8 bit data
  listen: 0,			// no loopback
  mm: 0,			// idle-line
  ckpl: 0,			// non-inverted clock
  urxse: 0,			// start edge off
  urxeie: 1,			// error interrupt enabled
  urxwie: 0,			// rx wake up disabled
  utxe : 1,			// tx interrupt enabled
  urxe : 1			// rx interrupt enabled
} };


const msp430_uart_union_config_t sirf3_57600_serial_config = { {
  ubr:   UBR_4MHZ_57600,
  umctl: UMCTL_4MHZ_57600,
  ssel: 0x02,			// smclk selected (DCO, 4MHz)
  pena: 0,			// no parity
  pev: 0,			// no parity
  spb: 0,			// one stop bit
  clen: 1,			// 8 bit data
  listen: 0,			// no loopback
  mm: 0,			// idle-line
  ckpl: 0,			// non-inverted clock
  urxse: 0,			// start edge off
  urxeie: 1,			// error interrupt enabled
  urxwie: 0,			// rx wake up disabled
  utxe : 1,			// tx interrupt enabled
  urxe : 1			// rx interrupt enabled
} };

#endif	/* _H_MM3SIRF3_DEFS_h */
