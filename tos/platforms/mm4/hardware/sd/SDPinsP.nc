/*
 * Copyright (c) 2016 Eric B. Decker
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
 */

/**
 * @author Eric B. Decker <cire831@gmail.com>
 */

#include "mm4PortRegs.h"
#include "panic.h"

module SDPinsP {
  provides {
    interface SDHardware as HW;
  }
  uses {
    interface HplMsp430UsciB as Usci;
    interface Panic;
    interface Platform;
  }
}
implementation {

#include "platform_spi_sd.h"

  MSP430REG_NORACE(P3SEL);
  MSP430REG_NORACE(P5DIR);

  MSP430REG_NORACE(DMACTL0);
  MSP430REG_NORACE(DMA0CTL);
  MSP430REG_NORACE(DMA1CTL);

  MSP430REG_NORACE(DMA0DA);
  MSP430REG_NORACE(DMA0SA);
  MSP430REG_NORACE(DMA0SZ);

  MSP430REG_NORACE(DMA1DA);
  MSP430REG_NORACE(DMA1SA);
  MSP430REG_NORACE(DMA1SZ);


#define sd_panic(where, arg) do { call Panic.panic(PANIC_MS, where, arg, 0, 0, 0); } while (0)
#define  sd_warn(where, arg) do { call  Panic.warn(PANIC_MS, where, arg, 0, 0, 0); } while (0)

  uint8_t idle_byte = 0xff;
  uint8_t recv_dump[SD_BUF_SIZE];

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
#define SPI_8MHZ_DIV    1
#define SPI_FULL_SPEED_DIV SPI_8MHZ_DIV

const msp430_spi_union_config_t sd_full_config = { {
  ubr		: SPI_8MHZ_DIV,         /* full speed */
  ucmode	: 0,			/* 3 pin master, no ste */
  ucmst		: 1,
  uc7bit	: 0,			/* 8 bit */
  ucmsb		: 1,			/* msb first, compatible with msp430 usart */
  ucckpl	: 0,			/* inactive state low */
  ucckph	: 1,			/* data captured on rising, changed falling */
  ucssel	: 2,			/* smclk */
  } };


#ifdef notdef
/*
 * exp5438_gps, 5438a, USCI, SPI
 * x5 usci configuration
 * interface to si446x chip
 */

const msp430_usci_config_t si446x_spi_config = {
  /*
   * UCCKPH: 1,         data captured on rising edge
   * UCCKPL: 0,         inactive state is low
   * UCMSB:  1,
   * UC7BIT: 0,         8 bit
   * UCMST:  1,
   * UCMODE: 0b00,      3 wire SPI
   * UCSYNC: 1
   * UCSSEL: SMCLK
   */
  ctl0 : (UCCKPH | UCMSB | UCMST | UCSYNC),
  ctl1 : UCSSEL__SMCLK,
  br0  : 2,			/* 8MHz -> 4 MHz */
  br1  : 0,
  mctl : 0,                     /* Always 0 in SPI mode */
  i2coa: 0
};

#endif


  async command void HW.sd_spi_init() {
    call HW.sd_spi_disable();
    call HW.sd_off();
  }

  async command void HW.sd_spi_enable() {
    /*
     * ideally we want to flip the pins back and reconfigure and/or
     * simply take it out of reset.  But the interface doesn't export
     * a simple configurator.
     */
//    SD_PINS_SPI;			// switch pins over
    call Usci.setModeSpi(&sd_full_config);
  }

  async command void HW.sd_spi_disable() {
    SD_PINS_INPUT;			// all data pins inputs
    call Usci.resetUsci_n();            // just leave in reset
  }

  async command void HW.sd_access_enable()      { }
  async command void HW.sd_access_disable()     { }
  async command bool HW.sd_access_granted()     { return TRUE; }
  async command bool HW.sd_check_access_state() { return TRUE; }

  /*
   * see HW.sd_off for problems.
   *
   * assumes pin state as follows:
   *
   *   p5.0 sd_pwr_off	1pO
   *   p3.1 sd_mosi	0pO
   *   p3.2 sd_miso	0pO
   *   p3.3 sd_sck	0pO
   *   p5.4 sd_csn      0pO
   *
   *   sd_csn  1pO (holds csn high, deselected) (starts to power).
   *   set pins to Module (mosi, miso, and sck)
   *   power up
   */

  async command void HW.sd_on() {
    SD_CSN = 1;				// make sure tristated
    SD_PWR_ON;				// turn on.
  }

  /*
   * turn sd_off and switch pins back to port (1pI) so we don't power the
   * chip prior to powering it off.
   */
  async command void HW.sd_off() {
    SD_CSN = 1;				// tri-state by deselecting
    SD_PWR_OFF;				// kill power
  }

  async command bool HW.isSDPowered() {
    return (mmP5out.sd_pwr_off == 0);
  }

  async command void HW.sd_set_cs() { SD_CSN = 0; }
  async command void HW.sd_clr_cs() { SD_CSN = 1; }


  /*
   * DMA interrupt is only used for channel 0, RX for the SD.
   * When it goes off turn off the timeout timer and kick over to
   * sync level to finish.  The main SD driver code runs at sync level.
   */
  TOSH_SIGNAL( DMA_VECTOR ) {
    signal HW.sd_dma_interrupt();
  }


 #define DMA_DT_SINGLE DMADT_0
 #define DMA_SB_DB     DMASBDB
 #define DMA_DST_NC    DMADSTINCR_0
 #define DMA_DST_INC   DMADSTINCR_3
 #define DMA_SRC_NC    DMASRCINCR_0
 #define DMA_SRC_INC   DMASRCINCR_3

 #define DMA0_TSEL_B0RX (12<<0)	/* DMA chn 0, UCB0RXIFG */
 #define DMA1_TSEL_B0RX (12<<4)	/* DMA chn 1, UCB0RXIFG */
 #define DMA0_TSEL_B0TX (13<<0)	/* DMA chn 0, UCB0TXIFG */
 #define DMA1_TSEL_B0TX (13<<4)	/* DMA chn 1, UCB0TXIFG */

 #define DMA0_TSEL_RX_TRIG       DMA0_TSEL_B0RX
 #define DMA1_TSEL_RX_TRIG       DMA1_TSEL_B0RX


  /*
   * sd_start_dma:  Start up dma 0 and 1 for SD/SPI access.
   *
   * input:  sndbuf	pntr to transmit buffer.  If null 0xff will be sent.
   *         rcvbuf	pntr to recveive buffer.  If null no rx bytes will be stored.
   *         length     number of bytes to transfer.   Buffers are assumed to be this size.
   *
   * Channel 0 is used to RX and has priority.  Channel 1 for TX.
   *
   * If sndbuf is NULL, 0xff  will be sent on the transmit side to facilitate receiving.
   * If rcvbuf is NULL, a single byte recv_dump is used to receive incoming bytes.  This
   * is used for transmitting without receiving.
   *
   * To use for clocking the sd: sd_start_dma(NULL, NULL, 10)
   * To use for receiving:       sd_start_dma(NULL, rx_buf, 514)
   * To use for transmitting:    sd_start_dma(tx_buf, NULL, 514)
   *
   * The sector size (block size) is 512 bytes.  The additional two bytes are the crc.
   */

  async command void HW.sd_start_dma(uint8_t *sndptr, uint8_t *rcvptr, uint16_t length) {
    uint8_t first_byte;

    if (length == 0)
      sd_panic(23, length);

    DMA0CTL = 0;			/* hit DMAEN to disable dma engines */
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
      DMA0DA  = (uint16_t) recv_dump;

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

    DMACTL0 = DMA0_TSEL_RX_TRIG | DMA1_TSEL_RX_TRIG;

    DMA0CTL |= DMAEN;			/* must be done after TSELs get set */
    DMA1CTL |= DMAEN;

    SD_SPI_TX_BUF = first_byte;		/* start dma up */
  }


  /*
   * sd_wait_dma: busy wait for dma to finish.
   *
   * watches channel 0 till DMAEN goes off.  Channel 0 is RX.
   *
   * Also utilizes the SZ register to find out how many bytes remain
   * and assuming 1 us/byte a reasonable timeout (factor of 2).
   * A timeout kicks panic.
   *
   * This routine can be interrupted and time continues to run while
   * we are away.  This needs to be accounted for when checking for
   * timeouts.  While we were away did our operation complete?
   */

  async command void HW.sd_wait_dma(uint16_t length) {
    uint16_t max_timeout, t0;

    t0 = call Platform.usecsRaw();

    max_timeout = (length * 64);

    while (1) {
      if ((DMA0CTL & DMAEN) == 0)	/* check for completion */
	break;
      /*
       * We may have taken an interrupt just after checking to see if the
       * dma engine is still running.  This may put us into a timeout
       * condition.
       *
       * Only take the time out panic if the DMA engine is still running!
       */
      if (((call Platform.usecsRaw() - t0) > max_timeout) && (DMA0CTL & DMAEN)) {
	sd_panic(24, max_timeout);
	return;
      }
    }
    call HW.sd_stop_dma();
  }

  async command void HW.sd_stop_dma() {
    DMACTL0 = 0;			/* kick triggers */
    DMA0CTL = 0;			/* reset engines 0 and 1 */
    DMA1CTL = 0;
  }

  async command void HW.sd_dma_enable_int()     { DMA0CTL |=  DMAIE; }
  async command void HW.sd_dma_disable_int()    { DMA0CTL &= ~DMAIE; }

  async event void Panic.hook() { }
}
