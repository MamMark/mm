/*
 * Copyright (c) 2016-2017 Eric B. Decker
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
 */

#include <hardware.h>
#include <panic.h>
#include <platform_panic.h>
#include <msp432.h>
#include <msp432dma.h>

#ifndef PANIC_SD
enum {
  __pcode_sd = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_SD __pcode_sd
#endif

module SD0HardwareP {
  provides {
    interface Init;
    interface SDHardware as HW;
  }
  uses {
    interface HplMsp432Usci    as Usci;
    interface HplMsp432UsciInt as Interrupt;
    interface Msp432Dma        as DmaTX;
    interface Msp432Dma        as DmaRX;
    interface Panic;
    interface Platform;
  }
}
implementation {

#define SPI_PUT_GET_TO 1024
#define SPI_PARANOID

  typedef struct {                      /* only for full sectors */
    uint32_t dma_ops;
    uint32_t min_dma_time_us;
    uint32_t max_dma_time_us;
    uint32_t avg_dma_time_us;
  } dma_stats_t;

  norace dma_stats_t  dma_stats;
  norace uint32_t     dma_t0_us;

#define sd_panic(where, arg, arg1) do { \
    call Panic.panic(PANIC_SD, where, arg, arg1, 0, 0); \
  } while (0)

#define  sd_warn(where, arg)      do { \
    call  Panic.warn(PANIC_SD, where, arg, 0, 0, 0); \
  } while (0)

  uint8_t idle_byte = 0xff;
  uint8_t recv_dump[SD_BLOCKSIZE];

/*
 * The dev6a main cpu clock is 16MiHz, SMCLK (for periphs) is clocked at
 * 8MiHz.  The dev6a is a TI msp432p401r (exp-msp432p401r launch pad) dev
 * board with added mm6a peripherals.
 *
 * There is documentation that says initilization on the SD
 * shouldn't be done any faster than 400 KHz to be compatible
 * with MMC which is open drain.  We don't have to be compatible
 * with that.  We've tested at 8MHz and everything seems to
 * work fine.
 *
 * Normal operation occurs at 8MiHz.  The usci on the msp432 can be run as
 * fast as SMCLK.  Currently we run at 8MiHz.  The SPI runs at SMCLK/1 to
 * maximize its performance.  Timers run at SMCLK/8 (max divisor) to get
 * 1uis ticks.  Note the SD in SPI mode is documented is various places
 * that it can clock up to 25MHz.  So we should be safe.
 *
 * Dev6a, msp432, USCI, SPI
 * phase 0, polarity 1, msb, 8 bit, master,
 * mode 3 pin, sync.
 *
 * Various documents (none definitive) state that SDs in SPI mode should
 * use SPI mode 0, which seems to mean Pos Pulse, latch then shift.
 *
 * However, we have observed that PL 1 (inactive high) and PH 0 works fine.
 * Also since we have pull up resistors on all the signal lines we really
 * want to keep the lines high when we can.
 *
 * UCCKPH: 0,         shift 1st edge, captured on 2nd edge
 * UCCKPL: 1,         inactive state is high.
 * UCMSB:  1,
 * UC7BIT: 0,         8 bit
 * UCMST:  1,
 * UCMODE: 0b00,      3 wire SPI
 * UCSYNC: 1
 * UCSSEL: SMCLK
 */

const msp432_usci_config_t sd_spi_config = {
ctlw0 : (  EUSCI_A_CTLW0_CKPL        | EUSCI_A_CTLW0_MSB  |
           EUSCI_A_CTLW0_MST         | EUSCI_A_CTLW0_SYNC |
           EUSCI_A_CTLW0_SSEL__SMCLK),
  brw   : MSP432_SD_DIV,        /* see platform_clk_defs */
  mctlw : 0,                    /* Always 0 in SPI mode */
  i2coa : 0
};


  command error_t Init.init() {
    uint32_t t0, t1;

    call Usci.configure(&sd_spi_config, FALSE);

    /*
     * sent a first byte to force simo high.  We send, then clear the
     * return byte out to keep the h/w clean.
     *
     * The eUSCI isn't connected to the h/w yet so the transmit isn't seen
     * by the external h/w.  The cpu pins aren't connected to the eUSCI
     * until the SD is actually turned on.  This avoids powering the SD
     * through the I/O pins.
     */
    call Usci.setTxbuf(0xff);
    t0 = call Platform.usecsRaw();
    while (!call Usci.isRxIntrPending()) {
      t1 = call Platform.usecsRaw();
      if ((t1 - t0) > 1000) {
        sd_panic(13, t0, t1);
      }
    }
    call Usci.getRxbuf();
    return SUCCESS;
  }

  async command void HW.spi_check_clean() {
    uint8_t tmp;

    tmp = call Usci.getStat();
#ifdef SPI_PARANOID
    if (tmp & EUSCI_A_STATW_BUSY) {
      sd_warn(1, 0);
    }
    if (tmp & EUSCI_A_STATW_OE) {
      sd_warn(2, tmp);
      call Usci.getRxbuf();             /* clears overrun */
    }
    if (call Usci.isRxIntrPending()) {
      tmp = call Usci.getRxbuf();
      sd_warn(3, tmp);
    }
#else
    if (tmp & EUSCI_A_STATW_OE)
      call Usci.getRxbuf();             /* clears overrun */
    if (call Usci.isRxIntrPending()) {
      call Usci.getRxbuf();
#endif
  }


  async command uint8_t HW.spi_put(uint8_t tx_byte) {
    uint16_t i;

    call Usci.setTxbuf(tx_byte);

    i = SPI_PUT_GET_TO;
    while ( !(call Usci.isRxIntrPending()) && i > 0)
      i--;
    if (i == 0)				/* rx timeout */
      sd_warn(4, 0);
    i = call Usci.getStat();
    if (i & EUSCI_A_STATW_OE)
      sd_warn(5, i);

    return call Usci.getRxbuf();
  }


#define SG_SIZE 32
  norace uint16_t sg_ts[SG_SIZE];       /* spi get, eaves drop */
  norace uint8_t  sg[SG_SIZE];
  norace uint8_t  sg_nxt;

  async command uint8_t HW.spi_get() {
    uint16_t i;
    uint8_t  byte;

    call Usci.setTxbuf(0xff);

    i = SPI_PUT_GET_TO;
    while ( !call Usci.isRxIntrPending() && i > 0)
      i--;

    if (i == 0)				/* rx timeout */
      sd_warn(6, 0);

    i = call Usci.getStat();
    if (i & EUSCI_A_STATW_OE)
      sd_warn(7, i);

    byte = call Usci.getRxbuf();
    sg_ts[sg_nxt] = call Platform.usecsRaw();
    sg[sg_nxt++] = byte;
    if (sg_nxt >= SG_SIZE)
      sg_nxt = 0;
    return byte;
  }


  async command void HW.sd_spi_enable()  { }
  async command void HW.sd_spi_disable() { }

  async command void HW.sd_access_enable()      { }
  async command void HW.sd_access_disable()     { }
  async command bool HW.sd_access_granted()     { return TRUE; }
  async command bool HW.sd_check_access_state() { return TRUE; }

  async command void HW.sd_on() {
    SD0_CSN = 1;                // make sure tristated
    SD0_PWR_ENA = SD0_PWR_ENA_ON;
  }

  /*
   * turn sd_off.  note powering down the SD side of the translators.
   * we can leave the Ports set up the way it works normally.  There
   * is no need to switch to Port.
   */
  async command void HW.sd_off() {
    SD0_CSN = 1;                /* tri-state by deselecting */
    SD0_PWR_ENA = SD0_PWR_ENA_OFF;
  }

  async command bool HW.isSDPowered() { return TRUE; }

  async command void    HW.sd_set_cs()          { SD0_CSN = 0; }
  async command void    HW.sd_clr_cs()          { SD0_CSN = 1; }


  void calc_dma_stats() {
    uint32_t delta;
    uint64_t working;

    delta = call Platform.usecsRaw() - dma_t0_us;
    if (dma_stats.min_dma_time_us) {
      if (delta < dma_stats.min_dma_time_us)
        dma_stats.min_dma_time_us = delta;
    } else
      dma_stats.min_dma_time_us = delta;
    if (delta > dma_stats.max_dma_time_us)
      dma_stats.max_dma_time_us = delta;
    working = dma_stats.avg_dma_time_us * (dma_stats.dma_ops - 1);
    working += delta;
    dma_stats.avg_dma_time_us = working / dma_stats.dma_ops;
    dma_t0_us = 0;
  }


  async command void HW.sd_start_dma(uint8_t *sndptr, uint8_t *rcvptr, uint16_t length) {
    uint32_t control;

    if (length == 0 || (rcvptr == NULL && length > SD_BLOCKSIZE))
      sd_panic(8, length, 0);

    /*
     * Dma.dma_start_channel checks if the requested engine is already
     * running and panics if so.  No need to stop the channels here.
     */

    /*
     * set the receiver up first.
     *
     * if rcvptr is NULL we pull into recv_dump (512, big enough),  DSTINC always 8
     * SRCINC is always NONE (coming from the port).
     */
    control = UDMA_CHCTL_DSTINC_8 | UDMA_CHCTL_SRCINC_NONE |
      MSP432_DMA_SIZE_8 | UDMA_CHCTL_ARBSIZE_1 | MSP432_DMA_MODE_BASIC;
    rcvptr = rcvptr ? rcvptr : recv_dump;

    call DmaRX.dma_set_priority(1);             /* run RX with high priority */
    call DmaRX.dma_start_channel(SD0_DMA_RX_TRIGGER, length,
        rcvptr, (void *) &(SD0_DMA_RX_ADDR), control);

    /*
     * Set up the TX side
     *
     * if sndptr is NULL we pull from a single byte, idle_byte,  SRCINC will be 8 if coming
     * from sndptr, otherwise (idle_byte) NONE.  DSTINC is always NONE (going to the port).
     */
    control = UDMA_CHCTL_DSTINC_NONE | MSP432_DMA_SIZE_8 |
      UDMA_CHCTL_ARBSIZE_1 | MSP432_DMA_MODE_BASIC;
    if (sndptr) {
      control |= UDMA_CHCTL_SRCINC_8;
    } else {
      sndptr = &idle_byte;
      control |= UDMA_CHCTL_SRCINC_NONE;
    }

    call DmaTX.dma_set_priority(0);             /* run TX with normal priority */
    if (length == SD_BLOCKSIZE) {
      dma_stats.dma_ops++;
      dma_t0_us = call Platform.usecsRaw();
      if (!dma_t0_us)                           /* zero isn't allowed */
        dma_t0_us = call Platform.usecsRaw();   /* grab it again, should be good now */
    }
    call DmaTX.dma_start_channel(SD0_DMA_TX_TRIGGER, length,
        (void*) &(SD0_DMA_TX_ADDR), sndptr, control);
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
    uint32_t max_timeout, t0;
    uint32_t a, b;

    t0 = call Platform.usecsRaw();

    max_timeout = (length * 64);

    while (1) {
      if (call DmaRX.dma_complete())	/* check for completion */
	break;
      /*
       * We may have taken an interrupt just after checking to see if the
       * dma engine is still running.  This may put us into a timeout
       * condition.
       *
       * Only take the time out panic if the DMA engine is still running!
       */
      if (((call Platform.usecsRaw() - t0) > max_timeout) && (call DmaRX.dma_enabled())) {
	sd_panic(9, max_timeout, 0);
	return;
      }
    }
    a = call DmaTX.dma_enabled();
    b = call DmaRX.dma_enabled();
    if (a || b)
      sd_panic(10, a, b);
    call DmaTX.dma_clear_int();
    call DmaRX.dma_clear_int();
    if (dma_t0_us)                      /* nukes dma_t0_us */
      calc_dma_stats();
  }


  async command bool HW.sd_dma_active(){
    uint32_t a,b;

    a = call DmaTX.dma_enabled();
    b = call DmaRX.dma_enabled();
    return (a || b);
  }


  /* true says there was something to stop */
  async command bool HW.sd_stop_dma() {
    uint32_t a;

    a = call HW.sd_dma_active();
    call DmaTX.dma_stop_channel();
    call DmaRX.dma_stop_channel();
    dma_t0_us = 0;                      /* not watching anymore */
    return a;                           /* the hills have eyes  */
  }


  async command void HW.sd_dma_enable_int() {
    call DmaRX.dma_enable_int();
  }


  async command void HW.sd_dma_disable_int() {
    call DmaRX.dma_disable_int();
  }


  async event void DmaTX.dma_interrupted() {
    sd_panic(11, 0, 0);          /* shouldn't ever see this */
  }


  async event void DmaRX.dma_interrupted() {
    if (dma_t0_us)
      calc_dma_stats();
    signal HW.sd_dma_interrupt();
  }

  async event void Interrupt.interrupted(uint8_t iv) {
    sd_panic(12, iv, 0);        /* shouldn't ever see this */
  }

  async event void Panic.hook() { }
}
