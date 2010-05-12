/**
 * Copyright 2010 (c) Eric Decker
 * All rights reserved.
 *
 * @author Eric Decker
 */

#ifndef _H_PLATFORM_SD_SPI_H_
#define _H_PLATFORM_SD_SPI_H_

#include <msp430usci.h>

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

MSP430REG_NORACE(IFG2);
MSP430REG_NORACE(UCB0TXBUF);
MSP430REG_NORACE(UCB0RXBUF);
MSP430REG_NORACE(UCB0STAT);
MSP430REG_NORACE(DMA0CTL);

/* set for msp430f2618, usci_b0 spi */
#define SD_SPI_IFG		(IFG2)
#define SD_SPI_TX_RDY		(IFG2 & UCB0TXIFG)
#define SD_SPI_TX_BUF		(UCB0TXBUF)
#define SD_SPI_RX_RDY		(IFG2 & UCB0RXIFG)
#define SD_SPI_RX_BUF		(UCB0RXBUF)
#define SD_SPI_BUSY		(UCB0STAT & UCBUSY)
#define SD_SPI_CLR_RXINT	(IFG2 &=  ~UCB0RXIFG)
#define SD_SPI_CLR_TXINT	(IFG2 &=  ~UCB0TXIFG)
#define SD_SPI_SET_TXINT	(IFG2 |=   UCB0TXIFG)
#define SD_SPI_CLR_BOTH		(IFG2 &= ~(UCB0RXIFG | UCB0TXIFG))
#define SD_SPI_OVERRUN		(UCB0STAT & UCOE)
#define SD_SPI_CLR_OE		(UCB0RXBUF)
#define SD_SPI_OE_REG		(UCB0STAT)

/*
 * DMA control defines.  Makes things more readable.
 */

#define DMA_DT_SINGLE DMADT_0
#define DMA_SB_DB     DMASBDB
#define DMA_EN        DMAEN
#define DMA_DST_NC    DMADSTINCR_0
#define DMA_DST_INC   DMADSTINCR_3
#define DMA_SRC_NC    DMASRCINCR_0
#define DMA_SRC_INC   DMASRCINCR_3

#define DMA0_TSEL_B0RX (12<<0)	/* DMA chn 0, UCB0RXIFG */
#define DMA1_TSEL_B0RX (12<<4)	/* DMA chn 1, UCB0RXIFG */
#define DMA0_TSEL_B0TX (13<<0)	/* DMA chn 0, UCB0TXIFG */
#define DMA1_TSEL_B0TX (13<<4)	/* DMA chn 1, UCB0TXIFG */

#define DMA0_ENABLE_INT		(DMA0CTL |= DMAIE)
#define DMA0_DISABLE_INT	(DMA0CTL &= ~DMAIE)


/*
 * The MM4 is clocked at 8MHz.  (could go up to 16MHz)
 *
 * There is documentation that says initilization on the SD
 * shouldn't be done any faster than 400 KHz to be compatible
 * with MMC which is open drain.  We don't have to be compatible
 * with that.  We've tested at 8MHz and everything seems to
 * work fine.
 *
 * Normal operation occurs at 8MHz.  The usci on the 2618 can be
 * run as fast as smclk which can be set to be the main dco frequency
 * which is at 8MHz.  Currently we run at 8MHz.   The SPI runs at
 * DCO/1 to maximize its performance.  Timers run at DCO/8 (max
 * divisor) to get 1uis ticks.  If we increase DCO to 16 MHz there
 * is a problem with the main timer because the max divisor is
 * /8.  This impacts timing for all the timers.
 */

// #define SPI_400K_DIV 21
#define SPI_8MIHZ_DIV    1
#define SPI_FULL_SPEED_DIV SPI_8MIHZ_DIV

const msp430_spi_union_config_t sd_full_config = { {
  ubr		: SPI_8MIHZ_DIV,	/* full speed */
  ucmode	: 0,			/* 3 pin master, no ste */
  ucmst		: 1,
  uc7bit	: 0,			/* 8 bit */
  ucmsb		: 1,			/* msb first, compatible with msp430 usart */
  ucckpl	: 0,			/* inactive state low */
  ucckph	: 1,			/* data captured on rising, changed falling */
  ucssel	: 2,			/* smclk */
  } };

#endif    /* _H_PLATFORM_SD_SPI_H_ */
