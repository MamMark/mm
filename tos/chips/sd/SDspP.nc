/**
 * SDsp - low level Secure Digital storage driver
 * Split phase, event driven.
 *
 * Copyright (c) 2014: Eric B. Decker
 * Copyright (c) 2010, Eric B. Decker, Carl Davis
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

#include "msp430hardware.h"
#include "hardware.h"
#include "sd.h"
#include "sd_cmd.h"
#include "panic.h"

/*
 * when resetting.   How long to wait before trying to send the GO_OP
 * to the SD card again.  We let other things happen in the tinyOS system.
 */
#define GO_OP_POLL_TIME 4

#ifdef FAIL
#warning "FAIL defined, undefining, it should be an enum"
#undef FAIL
#endif

#define SD_PUT_GET_TO 1024
#define SD_PARANOID

typedef enum {
  SDS_IDLE = 0,
  SDS_RESET,
  SDS_READ,
  SDS_READ_DMA,
  SDS_WRITE,
  SDS_WRITE_DMA,
  SDS_WRITE_BUSY,
  SDS_ERASE,
  SDS_ERASE_BUSY,
} sd_state_t;

uint32_t w_t, w_diff;

/* sdsa_majik only looked at in SDsa, ints should be off and should always be atomic */
norace uint32_t sdsa_majik;


uint32_t sa_t0, sa_diff;
uint16_t sa_t3;

#define SDSA_MAJIK 0xAAAA5555


module SDspP {
  provides {
    interface SDread[uint8_t cid];
    interface SDwrite[uint8_t cid];
    interface SDerase[uint8_t cid];
    interface SDsa;			/* standalone */
    interface SDraw;			/* raw */
    interface Init;
  }
  uses {
    interface ResourceDefaultOwner;
    interface HplMsp430UsciB as Usci;
    interface Timer<TMilli> as SDtimer;
    interface LocalTime<TMilli> as lt;
    interface Hpl_MM_hw as HW;
    interface Panic;
  }
}

implementation {

#include "platform_spi_sd.h"

MSP430REG_NORACE(TAR);

  /*
   * main SDsp control cells.   The code can handle at most one operation at a time,
   * duh, we've only got one piece of h/w.
   *
   * SD_Arb provides for arbritration as well as assignment of client ids (cid).
   * SDsp however does not assume access control via the arbiter.  One could wire
   * in directly.  Rather it uses a state variable to control coherent access.  If
   * the driver is IDLE then it allows a client to start something new up.  It is
   * assumed that the client has gained access using the arbiter.  The arbiter is what
   * queuing of clients when the SD is already busy.  When the current client finishes
   * and releases the device, the arbiter will signal the next client to begin.
   *
   * sd_state  current driver state, non-IDLE if we are busy doing something.
   * cur_cid   client id of who has requested the activity.
   * blk_start holds the blk id we are working on
   * blk_end   if needed holds the last block working on (like for erase)
   * data_ptr  buffer pointer if needed.
   *
   * if sd_state is SDS_IDLE these cells are meaningless.
   */

#define SD_MAJIK 0x5aa5
#define CID_NONE 0xff;

  struct {
    uint16_t   majik_a;
    sd_state_t sd_state;
    uint8_t    cur_cid;			/* current client */
    uint32_t   blk_start, blk_end;
    uint8_t    *data_ptr;
    uint16_t   majik_b;
  } sdc;

  uint8_t idle_byte = 0xff;
  uint8_t recv_dump[SD_BUF_SIZE];

  norace sd_cmd_t sd_cmd;


  /* instrumentation
   *
   * need to think about these timeout and how to do with time vs. counts
   */
         uint16_t     sd_go_op_count;
  norace uint16_t     sd_read_tok_count;	/* how many times we've looked for a read token */
         uint16_t     sd_erase_busy_count;
  norace uint16_t     sd_write_busy_count;

         uint32_t     op_t0_ms;
  norace uint16_t     op_t0_us;

  norace uint16_t     sd_pwr_on_time_us;
         uint16_t     last_pwr_on_first_cmd_us;
         uint16_t     last_full_reset_time_us;

  uint32_t     max_reset_time_ms, last_reset_time_ms;
  uint16_t     max_reset_time_us, last_reset_time_us;

  uint32_t     max_read_time_ms,  last_read_time_ms;
  uint16_t     max_read_time_us,  last_read_time_us;

  uint32_t     max_write_time_ms, last_write_time_ms;
  uint16_t     max_write_time_us, last_write_time_us;

  uint32_t     max_erase_time_ms, last_erase_time_ms;
  uint16_t     max_erase_time_us, last_erase_time_us;


  void sd_cmd_crc();


#define sd_panic(where, arg) do { call Panic.panic(PANIC_MS, where, arg, 0, 0, 0); } while (0)
#define  sd_warn(where, arg) do { call  Panic.warn(PANIC_MS, where, arg, 0, 0, 0); } while (0)

  void sd_panic_idle(uint8_t where, uint16_t arg) {
    call Panic.panic(PANIC_MS, where, arg, 0, 0, 0);
    sdc.sd_state = SDS_IDLE;
    sdc.cur_cid = CID_NONE;
  }


  void sd_chk_clean() {
    uint8_t tmp;

#ifdef SD_PARANOID
    if (SD_SPI_BUSY) {
      sd_panic(16, 0);

      /*
       * how to clean out the transmitter?  It could be
       * hung.  Which would be weird.
       */
    }
    if (SD_SPI_OVERRUN) {
      sd_warn(17, SD_SPI_OE_REG);
      SD_SPI_CLR_OE;
    }
    if (SD_SPI_RX_RDY) {
      tmp = SD_SPI_RX_BUF;
      sd_warn(18, tmp);
    }
#else
    if (SD_SPI_OVERRUN)
      SD_SPI_CLR_OE;
    if (SD_SPI_RX_RDY)
      tmp = SD_SPI_RX_BUF;
#endif
  }


  void sd_put(uint8_t tx_data) {
    uint16_t i;

    SD_SPI_TX_BUF = tx_data;

    i = SD_PUT_GET_TO;
    while ( !(SD_SPI_RX_RDY) && i > 0)
      i--;
    if (i == 0)				/* rx timeout */
      sd_warn(19, 0);
    if (SD_SPI_OVERRUN)
      sd_warn(20, 0);

    tx_data = SD_SPI_RX_BUF;
  }


#define SG_SIZE 32
  norace uint16_t sg_tar[SG_SIZE];
  norace uint8_t  sg[SG_SIZE];
  norace uint8_t  sg_nxt;
  
  uint8_t sd_get() {
    uint16_t i;
    uint8_t  byte;

    SD_SPI_TX_BUF = 0xff;

    i = SD_PUT_GET_TO;
    while ( !SD_SPI_RX_RDY && i > 0)
      i--;

    if (i == 0)				/* rx timeout */
      sd_warn(21, 0);

    if (SD_SPI_OVERRUN)
      sd_warn(22, 0);

    byte = SD_SPI_RX_BUF;		/* also clears RXINT */
    sg_tar[sg_nxt] = TAR;
    sg[sg_nxt++] = byte;
    if (sg_nxt >= SG_SIZE)
      sg_nxt = 0;
    return byte;
  }


  /*
   * sd_start_dma:  Start up dma 0 and 1 for SD/SPI0 access.
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

  void sd_start_dma(uint8_t *sndptr, uint8_t *rcvptr, uint16_t length) {
    uint8_t first_byte;

    sd_chk_clean();
    if (length == 0)
      sd_panic(23, length);

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

    DMACTL0 = DMA0_TSEL_B0RX | DMA1_TSEL_B0RX;

    DMA0CTL |= DMA_EN;			/* must be done after TSELs get set */
    DMA1CTL |= DMA_EN;

    SD_SPI_TX_BUF = first_byte;		/* start dma up */
  }


  /*
   * sd_wait_dma: busy wait for dma to finish.
   *
   * watches channel 0 till DMA_EN goes off.  Channel 0 is RX.
   *
   * Also utilizes the SZ register to find out how many bytes remain
   * and assuming 1 us/byte a reasonable timeout (factor of 2).
   * A timeout kicks panic.
   *
   * This routine can be interrupted and time continues to run while
   * we are away.  This needs to be accounted for when checking for
   * timeouts.  While we were away did our operation complete?
   */

  void sd_wait_dma() {
    uint16_t max_count, t0;

    t0 = TAR;

    max_count = (DMA0SZ * 8);

    while (1) {
      if ((DMA0CTL & DMA_EN) == 0)	/* early bail check for completion */
	break;
      /*
       * We may have taken an interrupt just after checking to see if the
       * dma engine is still running.  This may put us into a timeout
       * condition.
       *
       * Only take the time out panic if the DMA engine is still running!
       */
      if (((TAR - t0) > max_count) && (DMA0CTL & DMA_EN)) {
	sd_panic(24, max_count);
	return;
      }
    }

    DMACTL0 = 0;			/* kick triggers */
    DMA0CTL = 0;			/* reset engines 0 and 1 */
    DMA1CTL = 0;
  }


  const uint8_t cmd55[] = {
    SD_APP_CMD, 0, 0, 0, 0, 0xff	/* when crc's get implemented need to change. */
  };


  /*
   * ACMDs have to be preceeded by a regular CMD55 to indicate that the next command
   * is from a different command set.
   *
   * CMD55 is a complete op, meaning it does cmd, response, and needs 1 extra byte
   * to finish clocking the SD front end.  We assume CS is already asserted.  We are
   * part of a complete op (ACMD41 for example).
   *
   * This command can be issued while the card is in reset so we ignore the IDLE
   * bit in the response.
   */

  void sd_send_cmd55() {
    uint16_t i;
    uint8_t  rsp, tmp;

    sd_chk_clean();
    sd_start_dma((uint8_t *) cmd55, recv_dump, sizeof(cmd55));
    sd_wait_dma();

    i=0;
    do {
      tmp = sd_get();
      i++;
    } while ((tmp == 0xff) && (i < SD_CMD_TIMEOUT));

    if (i >= SD_CMD_TIMEOUT) {
      sd_panic(25, i);
      return;
    }
    rsp = tmp;
    if (rsp & ~MSK_IDLE)
      sd_panic(26, rsp);
    tmp = sd_get();			/* close the cmd/rsp op */
  }


  /* sd_raw_cmd
   *
   * Send a command to the SD and receive a response from the SD.
   * The response is always a single byte and is the R1 response
   * as documented in the SD manual.
   *
   * raw_cmd is always part of a cmd sequence and that the caller
   * has asserted CS.
   *
   * raw_cmd does not change the SD card state in any other way
   * meaning it doesn't read any more bytes from the card for other
   * types of responses.
   *
   * Does not provide any kind of transactional control meaning
   * it doesn't send the extra clocks that are needed at the end
   * of a transaction, cmd/rsp, data transfer, etc.
   *
   * raw_cmd is responsible for computing the cmd block crc.
   *
   * return: R1 response byte,  0 says everything is wonderful.
   */

  uint8_t sd_raw_cmd() {
    uint16_t  i;
    uint8_t   tmp, rsp;

    sd_chk_clean();
    sd_cmd_crc();
    sd_start_dma(&sd_cmd.cmd, recv_dump, 6);
    sd_wait_dma();

    /* Wait for a response.  */
    i=0;
    do {
      tmp = sd_get();
      i++;
    } while ((tmp == 0xff) && (i < SD_CMD_TIMEOUT));

    rsp = tmp;				/* response byte */

    /* Just bail if we never got a response */
    if (i >= SD_CMD_TIMEOUT) {
      sd_panic(27, tmp);
      return 0xf0;
    }
    return rsp;
  }


  /*
   * send_command:
   *
   * send a simple command to the SD.  A simple command has an R1 response
   * and we handle it as a cmd/rsp transaction with the extra clocks at
   * the end to let the SD finish.
   *
   * cmd block crc computation is performed by raw_cmd.
   */
  uint8_t sd_send_command() {
    uint8_t rsp, tmp;

    SD_CSN = 0;
    rsp = sd_raw_cmd();
    tmp = sd_get();			/* close transaction out */
    SD_CSN = 1;
    return rsp;
  }


  /*
   * Send ACMD
   *
   * assume the command in the cmd buffer is an ACMD and should
   * be proceeded by a CMD55.
   *
   * closes the cmd/rsp transaction when done.
   */
  uint8_t sd_send_acmd() {
    uint8_t rsp, tmp;

    SD_CSN = 0;
    sd_send_cmd55();
    rsp = sd_raw_cmd();
    tmp = sd_get();
    SD_CSN = 1;
    return rsp;
  }


  /************************************************************************
   *
   * Init
   *
   ***********************************************************************/

  command error_t Init.init() {
    sdc.majik_a = SD_MAJIK;
    sdc.cur_cid = CID_NONE;
    sdc.majik_b = SD_MAJIK;
    return SUCCESS;
  }


  /************************************************************************
   *
   * Reset
   *
   * See SDsa for notes on reseting the SD card and powering it up.
   */

  /*
   * Reset the SD card:  start the reset sequence.
   *
   * SPI SD initialization sequence:
   * CMD0 (reset), CMD8, CMD55 (app cmd), ACMD41 (app_send_op_cond)
   *
   * See SDsa for details on power up timing.  Power up and down is
   * handled by the ResourceDefaultOwner (in this module).  Invokation
   * is handled by the Arbiter.  SDsa handles its own power up and down.
   * There needs to be enough delay prior to SDreset.reset.  We use 20
   * clock bytes to give us a bit of cushion.
   *
   * Power is turned on by the arbiter calling ResourceDefaultOwner.requested.
   * The reset sequence is started by clocking out bytes to clock the SD,
   * FORCE_IDLE is sent.  This drops CS while the command is sent which puts
   * the SD into SPI mode.  We then use a Timer to poll.  Each poll sends a
   * GO_OP to request operational mode.
   *
   * Once the SD indicates non-IDLE, we call ResourceDefaultOwner.release
   * to tell the arbiter to start granting.
   */

  void sd_start_reset(void) {
    sd_cmd_t *cmd;
    uint8_t   rsp;

    if (sdc.sd_state) {
      sd_panic_idle(28, sdc.sd_state);
      return;
    }

    op_t0_us = TAR;
    op_t0_ms = call lt.get();

    sdc.sd_state = SDS_RESET;
    sdc.cur_cid = CID_NONE;	        /* reset is not parameterized. */
    cmd = &sd_cmd;

    /*
     * Clock out at least 74 bits of idles (0xFF is 8 bits).  Thats 10 bytes. This allows
     * the SD card to complete its power up prior to us talking to the card.  We send
     * 40 to give a bit more timing cushion.  This gets us to about 200 us before the first
     * command is sent.  see SDsa.reset for more info.
     */

    SD_CSN = 1;				/* force to known state */
    sd_start_dma(NULL, recv_dump, 40);	/* send 40 0xff to clock SD */
    sd_wait_dma();

    /* Put the card in the idle state, non-zero return -> error */
    cmd->cmd = SD_FORCE_IDLE;		// Send CMD0, software reset
    cmd->arg = 0;
    last_pwr_on_first_cmd_us = TAR - sd_pwr_on_time_us;
    rsp = sd_send_command();
    if (rsp & ~MSK_IDLE) {		/* ignore idle for errors */
      sd_panic_idle(29, rsp);
      return;
    }

    /*
     * force the timer to go, which sends the first go_op.
     * eventually it will cause a resetDone to get sent.
     *
     * This switches us to the context that we want so the
     * signal for resetDone always comes from the same place.
     */
    sd_go_op_count = 0;		// Reset our counter for pending tries
    call SDtimer.startOneShot(0);
    return;
  }


  event void SDtimer.fired() {
    sd_cmd_t *cmd;
    uint8_t   rsp;

    switch (sdc.sd_state) {
      default:
      case SDS_ERASE_BUSY:		/* these are various timeout states */
      case SDS_WRITE_BUSY:		/* the timer went off which shouldn't happen */
      case SDS_WRITE_DMA:
      case SDS_READ_DMA:
	w_t = call lt.get();
	w_diff = w_t - op_t0_ms;
	rsp = sd_get();
	call Panic.panic(PANIC_MS, 30, sdc.sd_state, (w_diff >> 16), w_diff & 0xffff, 0);
	rsp = sd_get();
	return;

      case SDS_RESET:
	cmd = &sd_cmd;
	cmd->cmd = SD_GO_OP;            // Send ACMD41
	rsp = sd_send_acmd();
	if (rsp & ~MSK_IDLE) {		/* any other bits set? */
	  sd_panic_idle(31, rsp);
	  return;
	}

	if (rsp & MSK_IDLE) {
	  /* idle bit still set, means card is still in reset */
	  if (++sd_go_op_count >= SD_GO_OP_MAX) {
	    sd_panic_idle(32, sd_go_op_count);			// We maxed the tries, panic and fail
	    return;
	  }
	  call SDtimer.startOneShot(GO_OP_POLL_TIME);
	  return;
	}

	/*
	 * no longer idle, initialization was OK.
	 *
	 * If we were running with a reduced clock then this is the place to
	 * crank it up to full speed.  We do everything at full speed so there
	 * isn't currently any need.
	 */

	last_reset_time_us = TAR - op_t0_us;
	if (last_reset_time_us > max_reset_time_us)
	  max_reset_time_us = last_reset_time_us;

	last_reset_time_ms = call lt.get() - op_t0_ms;
	if (last_reset_time_ms > max_reset_time_ms)
	  max_reset_time_ms = last_reset_time_ms;

	last_full_reset_time_us = TAR - sd_pwr_on_time_us;

	sdc.sd_state = SDS_IDLE;
	sdc.cur_cid = CID_NONE;
	call ResourceDefaultOwner.release();
	return;
    }
  }


  /*
   * ResourceDefaultOwner.granted: power down the SD.
   *
   * reconfigure connections to the SD as input to avoid powering the chip
   * and power off.
   *
   * The HW.sd_off routine will put the i/o pins into a reasonable state to
   * avoid powering the SD chip and will kill power.  Also make sure that
   * the SPI module is held in reset.
   */

  async event void ResourceDefaultOwner.granted() {
    sd_pwr_on_time_us = 0;
    call HW.sd_off();
    call Usci.resetUsci_n();
  }


  task void sd_pwr_task() {
    sd_start_reset();
  }


  async event void ResourceDefaultOwner.requested() {
    sd_pwr_on_time_us = TAR;
    call HW.sd_on();
    call Usci.setModeSpi((msp430_spi_union_config_t *) &sd_full_config);
    post sd_pwr_task();
  }


  async event void ResourceDefaultOwner.immediateRequested() {
    sd_panic(0x80, 0);
  }


  /*
   * sd_check_crc
   *
   * i: data	pointer to a 512 byte + 2 bytes of CRC at end (512, 513)
   *
   * o: rtn	0 (SUCCESS) if crc is okay
   *		1 (FAIL) crc didn't check.
   *
   * SD_BLOCKSIZE is the size of the buffer (includes crc at the end)
   */

  int sd_check_crc(uint8_t *data, uint16_t crc) {
    return SUCCESS;
  }


  /* sd_compute_crc
   *
   * append a crc computed over the data buffer pointed at by data
   *
   * i: data	ptr to 512 bytes of data (with 2 additional bytes available
   *		at the end for the crc (total size 514).
   * o: none
   */

  void sd_compute_crc(uint8_t *data) {
    data[512] = 0;
    data[513] = 0;
  }


  /*
   * sd_cmd_crc
   *
   * set the crc for the command block
   *
   * currently we just force 0x95 which is the crc for GO_IDLE
   */

  void sd_cmd_crc() {
    sd_cmd.crc = 0x95;
  }


  uint16_t sd_read_status() {
    uint8_t  tmp, rsp, stat_byte;

    SD_CSN = 0;
    sd_cmd.cmd = SD_SEND_STATUS;
    sd_cmd.arg = 0;
    rsp = sd_raw_cmd();
    stat_byte = sd_get();
    tmp = sd_get();			/* close it off */
    SD_CSN = 1;
    return ((rsp << 8) | stat_byte);
  }


  /************************************************************************
   *
   * Read
   *
   ***********************************************************************/

  task void sd_read_task() {
    uint8_t tmp;
    uint8_t cid;

    /* Wait for the token */
    sd_read_tok_count++;
    tmp = sd_get();			/* read a byte from the SD */

    if ((tmp & MSK_TOK_DATAERROR) == 0 || sd_read_tok_count >= SD_READ_TOK_MAX) {
      /* Clock out a byte before returning, let SD finish */
      sd_get();

      /* The card returned an error, or timed out. */
      call Panic.panic(PANIC_MS, 33, tmp, sd_read_tok_count, 0, 0);
      cid = sdc.cur_cid;			/* remember for signaling */
      sdc.sd_state = SDS_IDLE;
      sdc.cur_cid = CID_NONE;
      signal SDread.readDone[cid](sdc.blk_start, sdc.data_ptr, FAIL);
      return;
    }

    /*
     * if we haven't seen the token yet then try again.  We just repost
     * ourselves to try again.  This lets others run.  We've observed
     * that in a tight loop it took about 50-60 loops before we saw the token
     * about 300 us.  Not enough to kick a timer off (ms granularity) but
     * long enough that we don't want to sit on the cpu.
     */
    if (tmp == 0xFF) {
      post sd_read_task();
      return;
    }

    if (tmp != SD_START_TOK)
      call Panic.panic(PANIC_MS, 34, tmp, sd_read_tok_count, 0, 0);

    /*
     * read the block (512 bytes) and include the crc (2 bytes)
     * we fire up the dma, turn on a timer to do a timeout, and
     * enable the dma interrupt to generate a h/w event when complete.
     */
    sdc.sd_state = SDS_READ_DMA;
    sd_start_dma(NULL, sdc.data_ptr, SD_BUF_SIZE);
    call SDtimer.startOneShot(SD_SECTOR_XFER_TIMEOUT);
    DMA0_ENABLE_INT;
    return;
  }


  void sd_read_dma_handler() {
    uint16_t crc;
    uint8_t  cid;

    cid = sdc.cur_cid;			/* remember for signalling */
    DMACTL0 = 0;			/* kick triggers */
    DMA0CTL = 0;			/* reset engines 0 and 1 */
    DMA1CTL = 0;

    SD_CSN = 1;				/* deassert CS */

    /* Send some extra clocks so the card can finish */
    sd_get();
    sd_get();

    crc = (sdc.data_ptr[512] << 8) | sdc.data_ptr[513];
    if (sd_check_crc(sdc.data_ptr, crc)) {
      sd_panic_idle(35, crc);
      signal SDread.readDone[cid](sdc.blk_start, sdc.data_ptr, FAIL);
      return;
    }

    /*
     * sometimes.  not sure of the conditions.  When using dma
     * the first byte will show up as 0xfe (something having
     * to do with the cmd response).  Check for this and if seen
     * flag it and re-read the buffer.  We don't keep trying so it
     * had better work.
     *
     * Haven't seen this in a while pretty sure it got cleaned up when
     * we got a better handle on the transaction sequence of the SD.
     */
    if (sdc.data_ptr[0] == 0xfe)
      sd_warn(36, sdc.data_ptr[0]);

    last_read_time_us = TAR - op_t0_us;
    if (last_read_time_us > max_read_time_us)
      max_read_time_us = last_read_time_us;

    last_read_time_ms = call lt.get() - op_t0_ms;
    if (last_read_time_ms > max_read_time_ms)
      max_read_time_ms = last_read_time_ms;

    sdc.sd_state = SDS_IDLE;
    sdc.cur_cid = CID_NONE;
    signal SDread.readDone[cid](sdc.blk_start, sdc.data_ptr, SUCCESS);
  }


  /*
   * SDread.read: read a 512 byte block from the SD
   *
   * input:  blockaddr     block to read.  (max 23 bits)
   *         data          pointer to data buffer, assumed 514 bytes
   * output: rtn           0 call successful, err otherwise
   *
   * if the return is SUCCESS, it is guaranteed that a readDone event
   * will be signalled.
   */

  command error_t SDread.read[uint8_t cid](uint32_t blockaddr, uint8_t *data) {
    sd_cmd_t *cmd;
    uint8_t   rsp;

    if (sdc.sd_state) {
      sd_panic_idle(37, sdc.sd_state);
      return EBUSY;
    }

    op_t0_us = TAR;
    op_t0_ms = call lt.get();

    sdc.sd_state = SDS_READ;
    sdc.cur_cid = cid;
    sdc.blk_start = blockaddr;
    sdc.data_ptr = data;

    cmd = &sd_cmd;

    /* Need to add size checking, 0 = success */
    cmd->cmd = SD_READ_BLOCK;
    cmd->arg = (sdc.blk_start << SD_BLOCKSIZE_NBITS);

    if ((rsp = sd_send_command())) {
      sd_panic_idle(38, rsp);
      return FAIL;
    }

    /*
     * The SD card can take some time before it says continue.
     * We've seen upto 300-400 us before it says continue.
     * kick to a task to let other folks run.
     */
    SD_CSN = 0;				/* rassert to continue xfer */
    sd_read_tok_count = 0;
    post sd_read_task();
    return SUCCESS;
  }


  /************************************************************************
   *
   * Write
   *
   */

  task void sd_write_task() {
    uint16_t i;
    uint8_t  tmp;
    uint8_t  cid;

    /* card is busy writing the block.  ask if still busy. */

    tmp = sd_get();
    sd_write_busy_count++;
    if (tmp != 0xff) {			/* protected by timeout timer */
      post sd_write_task();
      return;
    }
    call SDtimer.stop();		/* write busy done, kill timeout timer */
    SD_CSN = 1;				/* deassert CS */

    i = sd_read_status();
    if (i)
      sd_panic(39, i);

    last_write_time_us = TAR - op_t0_us;
    if (last_write_time_us > max_write_time_us)
      max_write_time_us = last_write_time_us;

    last_write_time_ms = call lt.get() - op_t0_ms;
    if (last_write_time_ms > max_write_time_ms)
      max_write_time_ms = last_write_time_ms;

    if (last_write_time_ms > SD_WRITE_WARN_THRESHOLD) {
      call Panic.warn(PANIC_MS, 128, (sdc.blk_start >> 16), (sdc.blk_start & 0xffff),
		      (last_write_time_ms >> 16), (last_write_time_ms &0xffff));
    }
    cid = sdc.cur_cid;
    sdc.sd_state = SDS_IDLE;
    sdc.cur_cid = CID_NONE;
    signal SDwrite.writeDone[cid](sdc.blk_start, sdc.data_ptr, SUCCESS);
  }


  void sd_write_dma_handler() {
    uint8_t  tmp;
    uint16_t i;
    uint8_t  cid;

    DMACTL0 = 0;			/* kick triggers */
    DMA0CTL = 0;			/* reset engines 0 and 1 */
    DMA1CTL = 0;

    /*
     * After the data block is accepted the SD sends a data response token
     * that tells whether it accepted the block.  0x05 says all is good.
     */
    tmp = sd_get();
    if ((tmp & 0x1F) != 0x05) {
      i = sd_read_status();
      call Panic.panic(PANIC_MS, 40, tmp, i, 0, 0);
      cid = sdc.cur_cid;		/* remember for signals */
      sdc.cur_cid = CID_NONE;
      sdc.sd_state = SDS_IDLE;
      signal SDwrite.writeDone[cid](sdc.blk_start, sdc.data_ptr, FAIL);
      return;
    }

    /*
     * the SD goes busy until the block is written.  (busy is data out low).
     * we poll using a task.
     *
     * We also start up a timeout timer to protect against hangs.
     */
    sd_write_busy_count = 0;
    sdc.sd_state = SDS_WRITE_BUSY;
    call SDtimer.startOneShot(SD_WRITE_BUSY_TIMEOUT);
    post sd_write_task();
  }


  command error_t SDwrite.write[uint8_t cid](uint32_t blockaddr, uint8_t *data) {
    sd_cmd_t *cmd;
    uint8_t   rsp;

    if (sdc.sd_state) {
      sd_panic_idle(41, sdc.sd_state);
      return EBUSY;
    }

    op_t0_us = TAR;
    op_t0_ms = call lt.get();

    sdc.sd_state = SDS_WRITE;
    sdc.cur_cid = cid;
    sdc.blk_start = blockaddr;
    sdc.data_ptr = data;

    cmd = &sd_cmd;

    sd_compute_crc(data);
    cmd->arg = (sdc.blk_start << SD_BLOCKSIZE_NBITS);

    cmd->cmd = SD_WRITE_BLOCK;
    if ((rsp = sd_send_command())) {
      sd_panic_idle(42, rsp);
      return FAIL;
    }

    SD_CSN = 0;				/* reassert to continue xfer */

    /*
     * The SD needs a write token, send it first then fire
     * up the dma.
     */
    sd_put(SD_START_TOK);

    /*
     * send the sector data, include the 2 crc bytes
     * start the dma, enable a time out to monitor the h/w
     * and enable the dma h/w interrupt to generate the h/w event.
     */
    sdc.sd_state = SDS_WRITE_DMA;
    sd_start_dma(data, recv_dump, SD_BUF_SIZE);
    call SDtimer.startOneShot(SD_SECTOR_XFER_TIMEOUT);
    DMA0_ENABLE_INT;
    return SUCCESS;
  }



  /************************************************************************
   *
   * SDerase.erase
   *
   */

  task void sd_erase_task() {
    uint8_t  tmp;
    uint8_t  cid;

    /*
     * card is busy erasing the block.  ask if still busy.
     */
    tmp = sd_get();
    sd_erase_busy_count++;
    if (tmp != 0xff) {			/* protected by timeout timer */
      post sd_erase_task();
      return;
    }
    call SDtimer.stop();		/* busy done, kill timeout */
    SD_CSN = 1;				/* deassert CS */

    last_erase_time_us = TAR - op_t0_us;
    if (last_erase_time_us > max_erase_time_us)
      max_erase_time_us = last_erase_time_us;

    last_erase_time_ms = call lt.get() - op_t0_ms;
    if (last_erase_time_ms > max_erase_time_ms)
      max_erase_time_ms = last_erase_time_ms;

    cid = sdc.cur_cid;
    sdc.sd_state = SDS_IDLE;
    sdc.cur_cid = CID_NONE;
    signal SDerase.eraseDone[cid](sdc.blk_start, sdc.blk_end, SUCCESS);
  }


  command error_t SDerase.erase[uint8_t cid](uint32_t blk_s, uint32_t blk_e) {
    sd_cmd_t *cmd;
    uint8_t   rsp;

    if (sdc.sd_state) {
      sd_panic_idle(43, sdc.sd_state);
      return EBUSY;
    }

    op_t0_us = TAR;
    op_t0_ms = call lt.get();

    sdc.sd_state = SDS_ERASE;
    sdc.cur_cid = cid;
    sdc.blk_start = blk_s;
    sdc.blk_end = blk_e;

    cmd = &sd_cmd;

    /*
     * send the start and then the end
     */
    cmd->arg = sdc.blk_start << SD_BLOCKSIZE_NBITS;
    cmd->cmd = SD_SET_ERASE_START;
    if ((rsp = sd_send_command())) {
      sd_panic_idle(44, rsp);
      return FAIL;
    }

    cmd->arg = sdc.blk_end << SD_BLOCKSIZE_NBITS;
    cmd->cmd = SD_SET_ERASE_END;
    if ((rsp = sd_send_command())) {
      sd_panic_idle(45, rsp);
      return FAIL;
    }

    cmd->cmd = SD_ERASE;
    if ((rsp = sd_send_command())) {
      sd_panic_idle(46, rsp);
      return FAIL;
    }

    SD_CSN = 0;				/* reassert to continue xfer */

    sd_erase_busy_count = 0;
    sdc.sd_state = SDS_ERASE_BUSY;
    call SDtimer.startOneShot(SD_ERASE_BUSY_TIMEOUT);
    post sd_erase_task();
    return SUCCESS;
  }


  /*************************************************************************
   *
   * SDsa: standalone SD implementation, no split phase, no clients
   *
   * We run the SD in SPI mode.  This is accomplished by setting CSN (chip
   * select, low true) to 0 and sending the FORCE_IDLE command.
   *
   * Steps:
   *
   *    1) turn on the SD.
   *    2) Configure USCI h/w for SPI mode.
   *    3) need to wait the initilization delay, supply voltage builds
   *	   to bus master voltage.  doc says maximum of 1ms, 74 clocks
   *	   and supply ramp up time.  But unclear how long is the actual
   *	   minimum.
   *	4) send FORCE_IDLE, sd_send_command also lowers CSN (low true).
   *	5) Repeatedly send GO_OP (ACMD41) to take the SD out of idle (what
   *	   they call reset).
   *
   *************************************************************************/

  /*
   * return TRUE if in standalone.
   *
   * Standalone code can panic.  provide a mechanism so panic can tell if
   * in standalone and special handling is needed.
   *
   * we have a majik number in the sdc (control block).  If this majik is
   * the SDSA_MAJIK then we are in standalone.
   */
  async command bool SDsa.inSA() {
    if (sdsa_majik == SDSA_MAJIK)
      return TRUE;
    return FALSE;
  }


  async command void SDsa.reset() {
    sd_cmd_t *cmd;                // Command Structure
    uint8_t rsp;
    uint16_t sa_op_cnt;

    sdsa_majik = SDSA_MAJIK;
    call HW.sd_on();
    call Usci.setModeSpi((msp430_spi_union_config_t *) &sd_full_config);

    /*
     * send 800 clocks, 100 bytes.  about 240 us.  This satisfies
     * sending 74 clocks but is significantly short of the 1 ms called
     * out in the doc.  But it seems to work.  Seems to depend on whose
     * SD card we are using.
     */
    sd_start_dma(NULL, recv_dump, 256);
    sd_wait_dma();

    cmd = &sd_cmd;
    cmd->cmd = SD_FORCE_IDLE;		// Send CMD0, software reset
    cmd->arg = 0;
    rsp = sd_send_command();
    if (rsp & ~MSK_IDLE) {		/* ignore idle for errors */
      sd_panic(47, rsp);
      return;
    }

    /*
     * SD_GO_OP_MAX is set for normal operation which is polled every 4 or so ms.
     * SA hits it in a tight loop, so we increase the max allowed to be 8 times
     * normal.
     */
    sa_op_cnt = 0;
    do {
      sa_op_cnt++;
      cmd->cmd = SD_GO_OP;		// Send CMD0, software reset
      rsp = sd_send_acmd();
    } while ((rsp & MSK_IDLE) && (sa_op_cnt < (SD_GO_OP_MAX * 8)));

    nop();
    if (sa_op_cnt >= (SD_GO_OP_MAX * 8))
      sd_panic(48, sa_op_cnt);
  }


  async command void SDsa.off() {
    call HW.sd_off();
    call Usci.resetUsci_n();
    sdsa_majik = 0;
  }


  async command void SDsa.read(uint32_t blk_id, uint8_t *buf) {
    sd_cmd_t *cmd;
    uint8_t   rsp, tmp;
    uint16_t  crc;

    cmd = &sd_cmd;

    /* Need to add size checking, 0 = success */
    cmd->cmd = SD_READ_BLOCK;
    cmd->arg = (blk_id << SD_BLOCKSIZE_NBITS);

    /* send read data command */
    SD_CSN = 0;
    rsp = sd_raw_cmd();                 /* clean, crc, send, get response */

    sd_read_tok_count = 0;

    /* read till we get a start token or timeout */
    do {
      sd_read_tok_count++;
      tmp = sd_get();			/* read a byte from the SD */

      if (((tmp & MSK_TOK_DATAERROR) == 0) || (sd_read_tok_count >= SD_READ_TOK_MAX)) {
	/*
	 *Clock out a byte before returning, let SD finish
	 */
	sd_get();
        call Panic.panic(PANIC_MS, 49, tmp, sd_read_tok_count, 0, blk_id);
	return;
      }

      if (tmp != 0xFF)
	break;

    } while ((sd_read_tok_count < SD_READ_TOK_MAX) || (tmp == 0xFF));

    if (tmp != SD_START_TOK) {
      call Panic.panic(PANIC_MS, 50, tmp, sd_read_tok_count, 0, blk_id);
      return;
    }

    /*
     * read the block (512 bytes) and include the crc (2 bytes)
     * we fire up the dma, turn on a timer to do a timeout, and
     * enable the dma interrupt to generate a h/w event when complete.
     */
    sd_start_dma(NULL, buf, SD_BUF_SIZE);
    sd_wait_dma();
    SD_CSN = 1;                  /* deassert the SD card */

    sd_get();
    sd_get();

    crc = (buf[512] << 8) | buf[513];
    if (sd_check_crc(buf, crc)) {
      sd_panic(51, crc);
      return;
    }
  }


  async command void SDsa.write(uint32_t blk_id, uint8_t *buf) {
    sd_cmd_t *cmd;
    uint8_t   rsp, tmp;
    uint16_t  t, last_tar, tar_wraps;

    cmd = &sd_cmd;
    sd_compute_crc(buf);

    cmd->arg = (blk_id << SD_BLOCKSIZE_NBITS);
    cmd->cmd = SD_WRITE_BLOCK;
    if ((rsp = sd_send_command()))
      sd_panic(52, rsp);

    SD_CSN = 0;
    sd_put(SD_START_TOK);
    sd_start_dma(buf, recv_dump, SD_BUF_SIZE);
    sd_wait_dma();

    /*
     * After the data block is accepted the SD sends a data response token
     * that tells whether it accepted the block.  0x05 says all is good.
     */
    tmp = sd_get();
    if ((tmp & 0x1F) != 0x05) {
      t = sd_read_status();
      call Panic.panic(PANIC_MS, 53, tmp, t, 0, blk_id);
      return;
    }

    /*
     * The SD can take a variable amount of time to do the actual write.
     * This depends upon the status of the block being written.   The SD
     * handles bad blocks automatically and the block in question can take
     * a while to write when it has started to go bad.  We have observed
     * anywhere from a nominal 3ms to > 120ms when the block is thinking
     * about going bad.
     *
     * The largest timeout we can get with just TAR is 64Ki us, which is
     * about 64+ ms.  So we implement a wrap counter.
     */
    last_tar = 0;
    TAR = 0;			/* reset to 0, easier to deal with */
    tar_wraps = 0;
    sd_write_busy_count = 0;

    /*
     * while busy writing, card is indicating busy, Data line low.  Wait until
     * we see one full byte of 1's to indicate not busy.
     */
    do {				/* count how many iterations and time */
      sd_write_busy_count++;
      tmp =  sd_get();
      if (tmp == 0xFF)
	break;

      if ((t = TAR) < last_tar) {
	if (++tar_wraps > 5)
	  call Panic.panic(PANIC_MS, 54, tar_wraps, t,
			   (blk_id >> 16), blk_id & 0xffff);
      }
      last_tar = t;
    } while (1);

    SD_CSN = 1;				/* deassert. */
    t = sd_read_status();
    if (t)
      call Panic.panic(PANIC_MS, 55, tmp, t, (blk_id >> 16), blk_id & 0xffff);
  }


  /*************************************************************************
   *
   * SDraw: raw interface to SD card from test programs.
   *
   *************************************************************************/

  command void SDraw.start_op() {
    SD_CSN = 0;
  }


  command void SDraw.end_op() {
    uint8_t tmp;

    tmp = sd_get();
    SD_CSN = 1;
  }


  command uint8_t SDraw.get() {
    return sd_get();
  }


  command void SDraw.put(uint8_t byte) {
    sd_put(byte);
  }


  /*
   * return pointer to the global command block
   */
  command sd_cmd_t *SDraw.cmd_ptr() {
    return &sd_cmd;
  }


  /*
   * send the command, return response (R1) for the
   * command loaded into the command block.
   *
   * This is a complete op.
   */
  command uint8_t SDraw.send_cmd() {
    return sd_send_command();
  }


  /*
   * send the ACMD loaded into the command block.  It is assumed
   * that the command in the command block is an ACMD and should
   * be proceeded by CMD55.
   *
   * This is NOT a complete op.  start_op and end_op have
   * to used to begin and end the SD op.
   */
  command uint8_t SDraw.raw_acmd() {
    sd_send_cmd55();
    return sd_raw_cmd();
  }


  /*
   * send the CMD loaded into the command block.
   *
   * This is NOT a complete op.  start_op and end_op have
   * to used to begin and end the SD op.
   */
  command uint8_t SDraw.raw_cmd() {
    return sd_raw_cmd();
  }


  command void SDraw.send_recv(uint8_t *tx, uint8_t *rx, uint16_t len) {
    sd_start_dma(tx, rx, len);
    sd_wait_dma();
  }


  /*************************************************************************
   *
   * DMA interaction
   *
   *************************************************************************/


  task void dma_task() {
    call SDtimer.stop();
    switch (sdc.sd_state) {
      case SDS_READ_DMA:
	sd_read_dma_handler();
	break;

      case SDS_WRITE_DMA:
	sd_write_dma_handler();
	break;

      default:
	sd_panic(56, sdc.sd_state);
	break;
    }
  }


  /*
   * DMA interrupt is only used for channel 0, RX for the SD.
   * When it goes off turn off the timeout timer and kick over to
   * sync level to finish.  The main SD driver code runs at sync level.
   */
  TOSH_SIGNAL( DMA_VECTOR ) {
    DMA0_DISABLE_INT;
    post dma_task();
  }


  default event void   SDread.readDone[uint8_t cid](uint32_t blk_id, uint8_t *buf, error_t error) {
    sd_panic(57, cid);
  }


  default event void SDwrite.writeDone[uint8_t cid](uint32_t blk, uint8_t *buf, error_t error) {
    sd_panic(58, cid);
  }


  default event void SDerase.eraseDone[uint8_t cid](uint32_t blk_start, uint32_t blk_end, error_t error) {
    sd_panic(59, cid);
  }

  async event void Panic.hook() { }
}
