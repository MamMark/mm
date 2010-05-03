/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */


uint8_t tx[64];
uint8_t rx[64];

module dmaP {
  uses {
    interface Boot;
    interface HplMsp430UsciB as Usci;
    interface HplMsp430UsciInterrupts as Interrupts;
  }
}

implementation {

#include "platform_sd_spi.h"

  void zero_rx(void) {
    uint16_t i;

    for (i = 0; i < 64; i++)
      rx[i] = 0;
  }


  void xfer(uint16_t number) {
    volatile register uint16_t t0, t1, t2;

    zero_rx();
    t0 = TAR;
    if (number == 0)
      return;

    /*
     * We use the dma engine to kick out the idle bytes.
     * To keep from overrunning, we use another dma channel
     * to suck bytes as they show up.
     *
     * priorities are 0 over 1 over 2 so we put RX on channel
     * 0 so they bytes get pulled prior to a pending tx byte.
     *
     * this should run bytes to the SD card as fast as possible.
     */

    DMA0CTL = DMA1CTL = 0;		/* hit DMA_EN to disable dma engines */
    DMA0SA  = (uint16_t) &SD_SPI_RX_BUF;
    DMA0DA  = (uint16_t) &rx;
    DMA0SZ  = number;
    DMA0CTL = DMA_DT_SINGLE | DMA_SB_DB | DMA_EN |
      DMA_DST_INC | DMA_SRC_NC;

    DMA1SA  = (uint16_t) &tx;
    DMA1DA  = (uint16_t) &SD_SPI_TX_BUF;
    DMA1SZ  = number;
    DMA1CTL = DMA_DT_SINGLE | DMA_SB_DB | DMA_EN |
      DMA_DST_NC | DMA_SRC_INC;

    DMACTL0 = DMA0_TSEL_B0RX | DMA1_TSEL_B0TX;

    t1 = TAR;
    SD_SPI_CLR_TXINT;
    SD_SPI_SET_TXINT;
    while (DMA0CTL & DMA_EN)		/* wait for chn 0 to finish */
      ;

    t2 = TAR;
    t2 = t2 - t1;
    t1 = t1 - t0;
    DMACTL0 = 0;			/* kick triggers */
    DMA0CTL = DMA1CTL = 0;		/* reset engines 0 and 1 */
  }


  event void Boot.booted() {
    uint16_t i;

    for (i = 0; i < 64; i++)
      tx[i] = i + 1;
    call Usci.setModeSpi((msp430_spi_union_config_t *) &sd_full_config);
    call Usci.setUstat(call Usci.getUstat() | UCLISTEN);
    xfer(10);
    SD_SPI_CLR_TXINT;
    xfer(10);
    xfer(10);
    SD_SPI_CLR_TXINT;
    xfer(1);
    SD_SPI_CLR_TXINT;
    xfer(2);
    SD_SPI_CLR_TXINT;
    xfer(3);
    xfer(4);
    xfer(5);
    xfer(8);
    xfer(16);
    xfer(32);
  }

  async event void Interrupts.txDone() {}
  async event void Interrupts.rxDone( uint8_t data ) {}
}
