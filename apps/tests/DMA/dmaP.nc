/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#define BUF_SIZE 512

uint8_t tx[BUF_SIZE];
uint8_t rx[BUF_SIZE];
uint8_t recv_dump;
uint8_t idle_byte = 0xff;

module dmaP {
  uses {
    interface Boot;
    interface HplMsp430UsciB as Usci;
    interface HplMsp430UsciInterrupts as Interrupts;
  }
}

implementation {

#include "platform_spi_sd.h"

  void zero_rx(void) {
    uint16_t i;

    for (i = 0; i < BUF_SIZE; i++)
      rx[i] = 0;
  }


  /*
   * sd_start_and_wait_dma:  Start up dma 0 and 1 in loopback for testing.
   *
   * Starts it up and waits for completion.  Times how long the actual
   * dma took.
   */

  void sd_start_and_wait_dma(uint8_t *sndptr, uint8_t *rcvptr, uint16_t length) {
    volatile register uint16_t t0, u1;
    volatile register uint16_t d1;
    uint8_t first_byte;

    t0 = TAR;

    DMA0CTL = 0;			/* hit DMA_EN to disable dma engines */
    DMA1CTL = 0;

    DMA0SA  = (uint16_t) &SD_SPI_RX_BUF;
    DMA0SZ  = length;
    DMA0CTL = DMA_DT_SINGLE | DMA_SB_DB | DMA_DST_NC | DMA_SRC_NC;
    if (rcvptr) {
      /*
       * note we know DMA_DST_NC is 0 so all we need to do is OR
       * in DMA_DST_INC to get the address to increment.
       */
      DMA0DA  = (uint16_t) rcvptr;
      DMA0CTL |= DMA_DST_INC;
    } else
      DMA0DA  = (uint16_t) &recv_dump;

    /*
     * There is a race condition that makes using an rx dma engine triggered
     * TSEL_xxRX and the tx engine triggered by TSEL_xxTX when running the
     * UCSI as an SPI.  The race condition causes the rxbuf to get overrun
     * very intermittently.  It loses a byte and the rx dma hangs.  We are
     * looking for the rx dma to complete but one byte got lost.
     *
     * Note this condition is difficult to duplicate.  We've seen it in the main
     * SDspP driver when using TSEL_TX to trigger channel 1.
     *
     * The work around is to trigger both dma channels on the RX trigger.  This
     * only sends a new TX byte after a fresh RX byte has been received and makes
     * sure that there isn't new data coming into the rx serial register which
     * would when complete overwrite the RXBUF causing an over run (and the lost
     * byte).
     *
     * Since the tx channel is triggered by an rx complete, we have to start
     * the transfer up by stuffing the first byte out.  The TXIFG flag is
     * ignored.
     */
    DMA1DA  = (uint16_t) &SD_SPI_TX_BUF;
    DMA1SZ  = length - 1;
    DMA1CTL = DMA_DT_SINGLE | DMA_SB_DB | DMA_DST_NC | DMA_SRC_NC;
    if (sndptr) {
      first_byte = sndptr[0];
      DMA1SA  = (uint16_t) (&sndptr[1]);
      DMA1CTL |= DMA_SRC_INC;
    } else {
      first_byte = 0xff;
      DMA1SA  = (uint16_t) &idle_byte;
    }

    DMACTL0 = DMA0_TSEL_B0RX | DMA1_TSEL_B0RX;

    DMA0CTL |= DMA_EN;			/* must be done after TSELs get set */
    DMA1CTL |= DMA_EN;

    t0 = TAR;

    SD_SPI_TX_BUF = first_byte;
    while (DMA0CTL & DMA_EN) {
      if ((TAR - t0) > 2048)
	nop();
    }

    u1 = TAR;
    d1 = u1 - t0;
    nop();

    DMACTL0 = 0;			/* kick triggers */
    DMA0CTL = DMA1CTL = 0;		/* reset engines 0 and 1 */
  }


#ifdef notdef
  /*
   * sd_wait_dma: busy wait for dma to finish.
   *
   * watches channel 0 till DMA_EN goes off.  Channel 0 is RX.
   *
   * Also utilizes the SZ register to find out how many bytes remain
   * and assuming 1uis/byte a reasonable timeout.  A timeout kicks panic.
   */

  void sd_wait_dma() {
    uint16_t max_count, t0;
    volatile register uint16_t u1;
    volatile register uint16_t d1;

    t0 = TAR;

    max_count = (DMA1SZ * 8);

    while (DMA0CTL & DMA_EN) {
      if ((TAR - t0) > max_count)
	nop();
    }

    u1 = TAR;
    d1 = u1 - t0;			/* total time */
    nop();

    DMACTL0 = 0;			/* kick triggers */
    DMA0CTL = DMA1CTL = 0;		/* reset engines 0 and 1 */
  }
#endif


  void xfer(uint16_t number) {
    volatile register uint16_t t0, t1;

    zero_rx();
    t0 = TAR;
    sd_start_and_wait_dma(tx, rx, number);
    t1 = TAR;
    t1 = t1 - t0;
    nop();
  }


  event void Boot.booted() {
    uint16_t i;

    for (i = 0; i < BUF_SIZE; i++)
      tx[i] = i + 1;
    call Usci.setModeSpi((msp430_spi_union_config_t *) &sd_full_config);
    call Usci.setUstat(call Usci.getUstat() | UCLISTEN);
//    call Usci.setUbr(2);
    xfer(10);
    xfer(1);
    xfer(2);
    xfer(3);
    xfer(4);
    xfer(5);
    xfer(8);
    xfer(16);
    xfer(32);
    xfer(512);
    for (i= 0; i < 256; i++)
      xfer(512);
    nop();
  }

  async event void Interrupts.txDone() {}
  async event void Interrupts.rxDone( uint8_t data ) {}
}
