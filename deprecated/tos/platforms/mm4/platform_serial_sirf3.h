/*
 * Copyright 2010 (c) Eric Decker
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 *
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * @author Eric Decker
 */

#ifndef _H_PLATFORM_SERIAL_SIRF3_H_
#define _H_PLATFORM_SERIAL_SIRF3_H_

#include "msp430usci.h"

/*
 * MM4, 2618, USCI
 */

const msp430_uart_union_config_t sirf3_4800_serial_config = { {
  ubr:		UBR_8MIHZ_4800,
  umctl:	UMCTL_8MIHZ_4800,
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
  ubr:		UBR_8MIHZ_57600,
  umctl:	UMCTL_8MIHZ_57600,
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


#endif	/* _H_PLATFORM_SERIAL_SIRF3_H_ */
