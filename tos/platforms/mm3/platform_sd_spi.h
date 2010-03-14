/**
 * Copyright 2010 (c) Eric Decker
 * All rights reserved.
 *
 * @author Eric Decker
 */

#ifndef _H_PLATFORM_SD_SPI_H_
#define _H_PLATFORM_SD_SPI_H_

#include <msp430usart.h>

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
MSP430REG_NORACE(U1TXBUF);
MSP430REG_NORACE(U1RXBUF);
MSP430REG_NORACE(U1TCTL);
MSP430REG_NORACE(U1RCTL);

/* set for msp430f1611, usart_1 spi */
#define SD_SPI_IFG		(IFG2)
#define SD_SPI_TX_RDY		(IFG2 & UTXIFG1)
#define SD_SPI_TX_BUF		(U1TXBUF)
#define SD_SPI_RX_RDY		(IFG2 & URXIFG1)
#define SD_SPI_RX_BUF		(U1RXBUF)
#define SD_SPI_BUSY		(!(U1TCTL & TXEPT) || SD_SPI_RX_RDY)
#define SD_SPI_CLR_RXINT	(IFG2 &= ~URXIFG1)
#define SD_SPI_CLR_BOTH		(IFG2 &= ~(URXIFG1 | UTXIFG1))
#define SD_SPI_OVERRUN		(U1RCTL & OE)
#define SD_SPI_CLR_OE		(U1RCTL &= ~OE)
#define SD_SPI_OE_REG		(U1RCTL)

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

#define DMA0_TSEL_U1RX (9<<0)	/* DMA chn 0, URXIFG1 */
#define DMA0_TSEL_U1TX (10<<0)	/* DMA chn 0, UTXIFG1 */
#define DMA1_TSEL_U1RX (9<<4)	/* DMA chn 1, URXIFG1 */

/*
 * The MM3 is clocked at 4MHz.
 *
 * when reseting the SD we don't want to be any faster
 * then 400KHz.   So we divide by 11 to make sure we are <= 400KHz.
 *
 * Normal operation occurs at 2MHz.  That is because the fastest
 * we can run the SPI usart h/w at is /2 so 4MHz/2.
 *
 * The default spi config in tos/chips/msp430/usart/msp430usart.h
 * has the the /2 and correct configuration.  We need another
 * one for the 400KHz.
 */

#define SPI_400K_DIV 11
#define SPI_2M_DIV    2
#define SD_FULL_SPEED_CONFIG msp430_spi_default_config

const msp430_spi_union_config_t sd_400K_config = { {
    ubr    : SPI_400K_DIV,
    ssel   : 2,				/* smclk */
    clen   : 1,				/* 8 bit */
    listen : 0,
    mm     : 1,				/* master */
    ckph   : 1,
    ckpl   : 0,
    stc    : 1				/* 3 pin mode */
  } };

#endif    /* _H_PLATFORM_SD_SPI_H_ */
