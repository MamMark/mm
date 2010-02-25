/**
 *
 * Copyright 2010 (c) Eric Decker
 * All rights reserved.
 *
 * @author Eric Decker
 */

#ifndef _H_MM3SD_DEFS_H
#define _H_MM3SD_DEFS_H

/*
 * for some reason the standard msp430 include files don't define
 * U1IFG but do define U0IFG.
 *
 * Also give better names for when we hit the Usart1 hardware directly.
 * We hit the hardware directly because we don't want the overhead nor
 * the assumptions that the generic, portable code uses.
 */

#define U1IFG IFG2

#define U1_OVERRUN  (U1RCTL & OE)
#define U1_RX_RDY   (IFG2 & URXIFG1)
#define U1_TX_EMPTY (U1TCTL & TXEPT)
#define U1_CLR_RX   (IFG2 &= ~URXIFG1)

#define SD_CSN mmP5out.sd_csn
#define SD_PWR_ON  (mmP5out.sd_pwr_off = 0)
#define SD_PWR_OFF (mmP5out.sd_pwr_off = 1)

/*
 * SD_PINS_OUT_0 will set SPI1/SD data pins to output 0.  (no longer
 * connected to the SPI module.  The values of these pins is assumed to be 0.
 * Direction of the pins is assumed to be output.  So the only thing that
 * needs to happen is changing from ModuleFunc to PortFunc.
 */

#define SD_PINS_OUT_0 do { P5SEL &= ~0x0e; } while (0)

/*
 * SD_PINS_SPI will connect the 3 data lines on the SD to the SPI.
 *
 * 5.4 CSN left alone (already assumed to be properly set)
 * 5.1-3 SDI, SDO, CLK set to SPI Module.
 */
#define SD_PINS_SPI   do { P5SEL |= 0x0e; } while (0)

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

#endif    /* _H_MM3SD_DEFS_H */
