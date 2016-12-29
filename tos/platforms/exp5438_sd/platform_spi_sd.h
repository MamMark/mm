/*
 * Copyright 2014, 2016 (c) Eric B. Decker
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
 * @author Eric B. Decker <cire831@gmail.com>
 *
 * Must be included from within an implementation block.
 */

#ifndef _H_PLATFORM_SPI_SD_H_
#define _H_PLATFORM_SPI_SD_H_

/*
 * Use better names for when we hit the SPI module hardware directly.
 * We hit the hardware directly because we don't want the overhead nor
 * the assumptions that the generic, portable code uses.
 *
 * SD_SPI_IFG:		interrupt flag register to check
 * SD_SPI_TX_RDY:	interrupt says tx can handle another byte
 * SD_SPI_TX_BUF:	how to send a tx byte
 * SD_SPI_RX_RDY:	interrupt says rx is available.
 * SD_SPI_RX_BUF:	how to get the rx byte
 * SD_SPI_BUSY:		is te spi doing anything?
 * SD_SPI_CLR_RXINT:	clear rx interrupt pending
 * SD_SPI_CLR_BOTH:	clear both tx and rx ints
 * SD_SPI_OVERRUN:	how to check for overrun.
 * SD_SPI_OE_REG:	where the oe bit lives
 */

MSP430REG_NORACE(UCB1IFG);
MSP430REG_NORACE(UCB1TXBUF);
MSP430REG_NORACE(UCB1RXBUF);
MSP430REG_NORACE(UCB1STAT);

MSP430REG_NORACE(DMACTL0);
MSP430REG_NORACE(DMA0CTL);
MSP430REG_NORACE(DMA1CTL);

MSP430REG_NORACE(DMA0DA);
MSP430REG_NORACE(DMA0SA);
MSP430REG_NORACE(DMA0SZ);

MSP430REG_NORACE(DMA1DA);
MSP430REG_NORACE(DMA1SA);
MSP430REG_NORACE(DMA1SZ);


/* set for msp430f5438a, usci_a1 spi */
#define SD_SPI_IFG		(UCB1IFG)
#define SD_SPI_TX_RDY		(UCB1IFG & UCTXIFG)
#define SD_SPI_TX_BUF		(UCB1TXBUF)
#define SD_SPI_RX_RDY		(UCB1IFG & UCRXIFG)
#define SD_SPI_RX_BUF		(UCB1RXBUF)
#define SD_SPI_BUSY		(UCB1STAT & UCBUSY)
#define SD_SPI_CLR_RXINT	(UCB1IFG &=  ~UCRXIFG)
#define SD_SPI_CLR_TXINT	(UCB1IFG &=  ~UCTXIFG)
#define SD_SPI_SET_TXINT	(UCB1IFG |=   UCTXIFG)
#define SD_SPI_CLR_BOTH		(UCB1IFG &= ~(UCRXIFG | UCTXIFG))
#define SD_SPI_OVERRUN		(UCB1STAT & UCOE)
#define SD_SPI_CLR_OE		(UCB1RXBUF)
#define SD_SPI_OE_REG		(UCB1STAT)

#endif    /* _H_PLATFORM_SPI_SD_H_ */
