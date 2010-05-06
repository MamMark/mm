/*
 * SDsp - low level Secure Digital storage driver
 * Split phase, event driven.
 *
 * Copyright (c) 2010, Eric B. Decker, Carl Davis
 * All rights reserved.
 */

#include "msp430hardware.h"
#include "hardware.h"
#include "sd.h"
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
  SDS_WRITE,
  SDS_ERASE,
} sd_state_t;


module SDspP {
  provides {
    /*
     * SDread, write, and erase are available to clients,
     * SDreset is not parameterized and is intended to only be called
     * by a power manager.
     */
    interface SDreset;
    interface SDread[uint8_t cid];
    interface SDwrite[uint8_t cid];
    interface SDerase[uint8_t cid];
    interface Init;
  }
  uses {
    interface HplMsp430UsciB as Umod;
//    interface HplMsp430UsciInterrupts as UsciInterrupts;
    interface Panic;
    interface Timer<TMilli> as SDtimer;
    interface LocalTime<TMilli> as lt;
  }
}

implementation {

#include "platform_sd_spi.h"
#include "sd_cmd.h"

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

  sd_state_t   sd_state;
  uint8_t      cur_cid;			/* current client */
  uint32_t     blk_start, blk_end;
  void	      *data_ptr;

  uint8_t idle_byte = 0xff;
  uint8_t recv_dump;

  sd_cmd_t sd_cmd;
  sd_ctl_t sd_ctl;


  /* instrumentation
   *
   * need to think about these timeout and how to do with time vs. counts
   */
  uint16_t     sd_r1b_timeout;
  uint16_t     sd_rd_timeout;
  uint16_t     sd_wr_timeout;
  uint16_t     sd_reset_timeout;
  uint16_t     sd_busy_timeout;
  uint16_t     sd_reset_idles;
  uint16_t     sd_go_op_count, sd_read_count;

  uint32_t     last_reset_time, reset_t0;
  uint32_t     last_read_time,  read_t0;


#define sd_panic(where, arg) do { call Panic.panic(PANIC_MS, where, arg, 0, 0, 0); } while (0)
#define  sd_warn(where, arg) do { call  Panic.warn(PANIC_MS, where, arg, 0, 0, 0); } while (0)

  void sd_panic_idle(uint8_t where, uint16_t arg) {
    call Panic.panic(PANIC_MS, where, arg, 0, 0, 0);
    sd_state = SDS_IDLE;
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
    volatile uint16_t t1, t2;

    t1 = TAR;
    SD_SPI_TX_BUF = tx_data;

    i = SD_PUT_GET_TO;
    while ( !(SD_SPI_RX_RDY) && i > 0)
      i--;
    if (i == 0)				/* rx timeout */
      sd_warn(19, 0);
    if (SD_SPI_OVERRUN)
      sd_warn(20, 0);
    tx_data = SD_SPI_RX_BUF;
    t2 = TAR;
    nop();
    t1 = t2 - t1;
  }


  uint8_t sd_get() {
    uint16_t i;

    SD_SPI_TX_BUF = 0xff;

    i = SD_PUT_GET_TO;
    while ( !SD_SPI_RX_RDY && i > 0)
      i--;

    if (i == 0)				/* rx timeout */
      sd_warn(21, 0);

    if (SD_SPI_OVERRUN)
      sd_warn(22, 0);

    return(SD_SPI_RX_BUF);		/* also clears RXINT */
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
   * To use for receiving:       sd_start_dma(NULL, rx_buf, 512)
   * To use for transmitting:    sd_start_dma(tx_buf, NULL, 512)
   *
   */

  void sd_start_dma(uint8_t *sndptr, uint8_t *rcvptr, uint16_t length) {
    volatile register uint16_t u0, u1;
    volatile register uint16_t d1;

    u0 = TAR;

    if (length == 0)
      sd_panic(50, length);

    DMA0CTL = 0;			/* hit DMA_EN to disable dma engines */
    DMA1CTL = 0;

    DMA0SA  = (uint16_t) &SD_SPI_RX_BUF;
    DMA0SZ  = length;
    DMA0CTL = DMA_DT_SINGLE | DMA_SB_DB | DMA_DST_NC | DMA_SRC_NC;
    if (rcvptr) {
      /* note we know DMA_DST_NC is 0 so all we need to do is or
       * in DMA_DST_INC to get the address to increment.
       */
      DMA0DA  = (uint16_t) rcvptr;
      DMA0CTL |= DMA_DST_INC;
    } else
      DMA0DA  = (uint16_t) &recv_dump;

    DMA1DA  = (uint16_t) &SD_SPI_TX_BUF;
    DMA1SZ  = length;
    DMA1CTL = DMA_DT_SINGLE | DMA_SB_DB | DMA_DST_NC | DMA_SRC_NC;
    if (sndptr) {
      DMA1SA  = (uint16_t) sndptr;
      DMA1CTL |= DMA_SRC_INC;
    } else
      DMA1SA  = (uint16_t) &idle_byte;

    DMACTL0 = DMA0_TSEL_B0RX | DMA1_TSEL_B0TX;

    /*
     * enable dma engines, do rx first.  tx shouldn't take off until we bring
     * txint back up.
     *
     * clear, enable, set
     */
    SD_SPI_CLR_TXINT;			/* make sure we get a rising edge */
    DMA0CTL |= DMA_EN;			/* must be done after TSELs get set */
    DMA1CTL |= DMA_EN;
    SD_SPI_SET_TXINT;

    u1 = TAR;
    d1 = u1 - u0;
    nop();
  }


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
	sd_panic(51, t0);
    }

    u1 = TAR;
    d1 = u1 - t0;			/* total time */
    nop();

    DMACTL0 = 0;			/* kick triggers */
    DMA0CTL = DMA1CTL = 0;		/* reset engines 0 and 1 */
  }


  const uint8_t cmd55[] = {
    SD_APP_CMD | 0x40,
    0, 0, 0, 0, 0xff,
  };


  int sd_send_cmd55() {
    uint16_t  i;
    uint8_t   tmp;
    sd_ctl_t *ctl;

    uint16_t t0;

    t0 = TAR;

    sd_start_dma((uint8_t *) cmd55, NULL, sizeof(cmd55));
    sd_wait_dma();

    i=0;
    do {
      tmp = sd_get();
      i++;
    } while((tmp > 127) && (i < SD_CMD_TIMEOUT));

    ctl = &sd_ctl;
    ctl->rsp55 = tmp;
    ctl->stage_count = i;

    if (i >= SD_CMD_TIMEOUT) {
      sd_warn(23, i);
      return FAIL;
    }

    tmp = sd_get();		/* finish the command */
    if (tmp != 0xff)		/* should be idle bus (high) */
      sd_warn(24, tmp);

    ctl->cmd55_delta = TAR - t0;
    return SUCCESS;
  }


  /* sd_send_command
   *
   * Send a command to the SD card waiting for the response (length given
   * in the command block.
   *
   * broken up into several stages and marked accordingly in the command block
   *
   * stage 1: For ACMDs send CMD55.  If not an acmd set rsp55 to 0x55 to flag.
   * stage 2: Send the command and wait for response.  Could time out.  stage_count
   *          holds the time out value if it does.
   * stage 3: extra clocks at end of cmd/response
   * stage 4: R1B busy wait.
   */

  int sd_send_command() {
    uint16_t  i;
    uint16_t  rsp_len;
    uint8_t   tmp;
    sd_cmd_t *cmd;
    sd_ctl_t *ctl;

    /* instrumentation
     *
     * u0: when the cmd starts.
     * u1: preliminaries.
     * u2: end of cmd
     * u3: end of response obtained.
     *
     * d1: preliminaries delta
     * d2: cmd delta
     * d3: response delta
     * t4: total time
     *
     * all times in uis.
     *
     */

    volatile register uint16_t u0, u1, u2, u3;
    volatile register uint16_t d1, d2, d3, t4;

    u0 = TAR;
    cmd = &sd_cmd;
    ctl = &sd_ctl;
    rsp_len = ctl->rsp_len & RSP_LEN_MASK;
    if (rsp_len != 1 && rsp_len != 2 && rsp_len != 5) {
      sd_panic(25, rsp_len);
      return FAIL;
    }

    /*
     * We used to check for chip select being down (CSN, low true)
     * but when ACMD processing was pulled out to simplify the code
     * sd_send_acmd now sets CSN and then calls us.  It doesn't hurt
     * anything to really make sure that it is set :-).
     */

    sd_chk_clean();
    SD_CSN = 0;

    u1 = TAR;
    d1 = u1 - u0;

    ctl->stage = 2;
    cmd->crc = 0x95;
    sd_start_dma(&cmd->cmd, NULL, 6);
    sd_wait_dma();

    u2 = TAR;
    d2 = u2 - u1;

    /* Wait for a response.  */
    i=0;
    do {
      tmp = sd_get();
      i++;
    } while ((tmp & 0x80) && (i < SD_CMD_TIMEOUT));

    cmd->rsp[0] = tmp;		/* first byte of the response */
    ctl->stage_count = i;

    /* Just bail if we never got a response */
    if (i >= SD_CMD_TIMEOUT) {
      /* stage 2 bail, timeout */
      sd_warn(28, tmp);
      SD_CSN = 1;
      return FAIL;
    }

    /* get rest of response if needed */
    i = 1;
    while (i < rsp_len)
      cmd->rsp[i++] = sd_get();

    ctl->stage = 3;
    tmp = sd_get();
    if (tmp != 0xff)
      sd_warn(29, tmp);

    /* If the response is a "busy" type (R1B), then there's some
     * special handling that needs to be done. The card will
     * output a continuous stream of zeros, so the end of the BUSY
     * state is signaled by any nonzero response. The bus idles
     * high.
     */
    if (ctl->rsp_len & R1B_FLAG) {
      ctl->stage = 4;
      i = 0;
      do {
	i++;
	tmp = sd_get();
      } while (tmp != 0xFF);
      sd_r1b_timeout = i;
//	ctl->stage_count = i;
      sd_put(0xff);
    }

    u3 = TAR;
    d3 = u3 - u2;
    t4 = u3 - u0;
    nop();
    ctl->stage = 0;
    SD_CSN = 1;
    return SUCCESS;
  }


  int sd_send_acmd() {
    uint16_t  rsp_len;
    uint8_t   tmp;
    sd_ctl_t *ctl;
    volatile register uint16_t u0, u1, u2;
    volatile register uint16_t d1, d2;

    u0 = TAR;

    ctl = &sd_ctl;
    rsp_len = ctl->rsp_len & RSP_LEN_MASK;
    if (rsp_len != 1 && rsp_len != 2 && rsp_len != 5) {
      sd_panic(25, rsp_len);
      return FAIL;
    }

    sd_chk_clean();
    SD_CSN = 0;
    ctl->stage = 1;

    u1 = TAR;
    d1 = u1 - u0;

    tmp = sd_send_cmd55();
    if (tmp) {
      /* failed, how odd */
      SD_CSN = 1;
      sd_warn(27, tmp);
      return FAIL;
    }

    u2 = TAR;
    d2 = u2 - u1;
    nop();

    return sd_send_command();
  }


  command error_t Init.init() {
    uint16_t i;

    sd_cmd.cmd = 0xf0;
    sd_cmd.arg = 0xf0f0f0f0;
    for (i = 0; i < 5; i++)
      sd_cmd.rsp[i] = 0xf0;

    sd_ctl.rsp_len = 0;
    sd_ctl.rsp55 = 0xf0;
    sd_ctl.stage = 0;
    sd_ctl.stage_count = 0;

    sd_r1b_timeout = 0xf0f0;
    sd_rd_timeout = 0xf0f0;
    sd_wr_timeout = 0xf0f0;
    sd_reset_timeout = 0xf0f0;
    sd_busy_timeout = 0xf0f0;
    return SUCCESS;
  }


  /* Set block length (size of data transaction)
   *
   * input:  length  size of block
   * output: rtn:    0 block length set okay.
   * non-zero, error return from send_command
   */

  int sd_set_blocklen(uint32_t length) {
    sd_cmd_t *cmd;
    sd_ctl_t *ctl;

    cmd = &sd_cmd;
    ctl = &sd_ctl;
    cmd->arg = length;
    cmd->cmd     = SD_SET_BLOCKLEN;
    ctl->rsp_len = SD_SET_BLOCKLEN_R;
    return sd_send_command();
  }


  /* Reset the SD card.
   * ret:      0,  card initilized
   * non-zero, error return
   *
   * SPI SD initialization sequence:
   * CMD0 (reset), CMD55 (app cmd), ACMD41 (app_send_op_cond), CMD58 (send ocr)
   */

  command error_t SDreset.reset() {
    sd_cmd_t *cmd;
    sd_ctl_t *ctl;
    volatile uint16_t u0, u1;

    u0 = TAR;
    if (sd_state) {
      sd_panic_idle(30, sd_state);
      return EBUSY;
    }

    reset_t0 = call lt.get();
    sd_state = SDS_RESET;
    cur_cid = -1;			/* reset is not parameterized. */
    cmd = &sd_cmd;
    ctl = &sd_ctl;

    /*
     * Originally, we set the divisor to produce 400KHz spi clock for backward compatibility
     * with MMC (open drain) chips.   The /1 seems to work okay so blow that off.
     */
    cmd->arg = 0;

    /* Clock out at least 74 bits of idles (0xFF).  Thats 10 bytes. This allows
     * the SD card to complete its power up prior to us talking to
     * the card.
     */

    SD_CSN = 1;				/* force to known state */
    sd_start_dma(NULL, NULL, 10);	/* send 10 0xff to clock SD */
    sd_wait_dma();

    u1 = TAR;
    u1 -= u0;
    nop();

    /* Put the card in the idle state, non-zero return -> error */
    cmd->cmd     = SD_FORCE_IDLE;       // Send CMD0, software reset
    ctl->rsp_len = SD_FORCE_IDLE_R;
    if (sd_send_command()) {
      sd_panic_idle(31, 0);
      return FAIL;
    }

    /*
     * force the timer to go, which sends the first go_op.
     * eventually it will cause a resetDone to get sent.
     *
     * This switches us to the context that we want so the
     * signal for resetDone always comes from the same place.
     */
    sd_go_op_count = 0;		// Reset our counter for Pending tries
    call SDtimer.startOneShot(0);
    u1 = TAR;
    u1 -= u0;
    nop();
    return SUCCESS;
  }


  void reset_finish() {
    sd_cmd_t *cmd;
    sd_ctl_t *ctl;

    cmd = &sd_cmd;
    ctl = &sd_ctl;
    cmd->cmd     = SD_SEND_OCR;
    ctl->rsp_len = SD_SEND_OCR_R;
    if (sd_send_command()) {
      sd_panic_idle(32, 0);
      signal SDreset.resetDone(FAIL);
      return;
    }

    /* At a very minimum, we must allow 3.3V. */
    if ((cmd->rsp[2] & MSK_OCR_33) != MSK_OCR_33) {
      sd_panic_idle(33, cmd->rsp[2]);
      signal SDreset.resetDone(FAIL);
      return;
    }

    /* Set the block length */
    if (sd_set_blocklen(SD_BLOCKSIZE)) {
      sd_panic_idle(34, 0);
      signal SDreset.resetDone(FAIL);
      return;
    }

    /* If we got this far, initialization was OK.
     *
     * If we were running with a reduced clock then this is the place to
     * crank it up to full speed.  We do everything at full speed so there
     * isn't currently any need.
     */
    last_reset_time = call lt.get() - reset_t0;
    nop();
    sd_state = SDS_IDLE;
    signal SDreset.resetDone(SUCCESS);
  }


  event void SDtimer.fired() {
    sd_cmd_t *cmd;
    sd_ctl_t *ctl;

    switch (sd_state) {

      default:
	return;

      case SDS_RESET:
	cmd = &sd_cmd;
	ctl = &sd_ctl;
	cmd->cmd     = SD_GO_OP;            //Send ACMD41
	ctl->rsp_len = SD_GO_OP_R;
	if (sd_send_acmd()) {
	  sd_panic_idle(35, 0);
	  signal SDreset.resetDone(FAIL);
	  return;
	}

	if (cmd->rsp[0] & MSK_IDLE) {
	  /* idle bit still set, means card is still in reset */
	  if (++sd_go_op_count >= SD_GO_OP_MAX) {
	    sd_panic_idle(36, sd_go_op_count);			// We maxed the tries, panic and fail
	    signal SDreset.resetDone(FAIL);
	    return;
	  }
	  call SDtimer.startOneShot(GO_OP_POLL_TIME);
	  return;
	}

	/*
	 * not idle finish things up.
	 */
	reset_finish();
	return;
    }
  }


  /*
   * sd_check_crc
   *
   * i: data	pointer to a 512 byte + 2 bytes of CRC at end (514)
   *
   * o: rtn	0 (SUCCESS) if crc is okay
   *		1 (FAIL) crc didn't check.
   *
   * SD_BLOCKSIZE+2 is the size of the buffer (2 is crc at end)
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
    //    data[512] = 0;
    //    data[513] = 0;
  }


  uint16_t sd_read_status() {
    sd_cmd_t *cmd;
    sd_ctl_t *ctl;
    uint16_t i;

    cmd = &sd_cmd;
    ctl = &sd_ctl;
    cmd->cmd     = SD_SEND_STATUS;
    ctl->rsp_len = SD_SEND_STATUS_R;
    if (sd_send_command())
      return(0xffff);
    i = (cmd->rsp[0] << 8) | cmd->rsp[1];
    return i;
  }


  task void sd_read_task() {
    uint8_t *d;
    uint16_t crc;

    sd_wait_dma();

    crc = sd_get();
    crc = crc << 8;
    crc |= sd_get();

    SD_CSN = 1;				/* deassert CS */

    /* Send some extra clocks so the card can finish */
    sd_start_dma(NULL, NULL, 2);
    sd_wait_dma();
    if (sd_check_crc(data_ptr, crc)) {
      sd_panic_idle(40, 0);
      signal SDread.readDone[cur_cid](blk_start, data_ptr, FAIL);
      return;
    }

    /*
     * sometimes.  not sure of the conditions.  When using dma
     * the first byte will show up as 0xfe (something having
     * to do with the cmd response).  Check for this and if seen
     * flag it and re-read the buffer.  We don't keep trying so it
     * had better work.
     */
    d = data_ptr;
    if (*d == 0xfe)
      sd_warn(41, *d);

    last_read_time = call lt.get() - read_t0;
    nop();
    signal SDread.readDone[cur_cid](blk_start, data_ptr, SUCCESS);
  }


  /*
   * SDread.read: read a 512 byte block from the SD
   *
   * input:  blockaddr     block to read.  (max 23 bits)
   *         data          pointer to data buffer, assumed 512 bytes
   * output: rtn           0 call successful, err otherwise
   */

  command error_t SDread.read[uint8_t cid](uint32_t blockaddr, void *data) {
    sd_cmd_t *cmd;
    sd_ctl_t *ctl;
    uint16_t i;
    uint8_t  tmp;

    if (sd_state) {
      sd_panic_idle(43, sd_state);
      return EBUSY;
    }

    read_t0 = call lt.get();

    sd_state = SDS_READ;
    cur_cid = cid;
    blk_start = blockaddr;
    data_ptr = data;

    cmd = &sd_cmd;
    ctl = &sd_ctl;

    /* Need to add size checking, 0 = success */
    cmd->cmd     = SD_READ_BLOCK;
    ctl->rsp_len = SD_READ_BLOCK_R;
    cmd->arg = (blk_start << SD_BLOCKSIZE_NBITS);

    if (sd_send_command()) {
      sd_panic_idle(39, 0);
      return FAIL;
    }

    /* Check for an error, like a misaligned read */
    if (cmd->rsp[0] != 0) {
      sd_panic_idle(39, cmd->rsp[0]);
      return FAIL;
    }

    /* Re-assert CS to continue the transfer */
    SD_CSN = 0;

    /* Wait for the token */
    i=0;
    do {
      tmp = sd_get();
      i++;
    } while ((tmp == 0xFF) && i < SD_READ_TIMEOUT);

    sd_rd_timeout = i;

    if ((tmp & MSK_TOK_DATAERROR) == 0 || i >= SD_READ_TIMEOUT) {
      /* Clock out a byte before returning, let SD finish */
      sd_get();

      /* The card returned an error, or timed out. */
      sd_panic_idle(39, 0);
      return FAIL;
    }

    sd_start_dma(NULL, data, SD_BLOCKSIZE);
    post sd_read_task();
    return SUCCESS;
  }


  /*
   * Start a write to the SD card using DMA.
   *
   * Clears DMA Int Enable.
   */

  error_t sd_start_write(uint32_t blockaddr, uint8_t *data) {
    uint8_t  tmp;
    sd_cmd_t *cmd;
    sd_ctl_t *ctl;

    cmd = &sd_cmd;
    ctl = &sd_ctl;

    sd_compute_crc(data);
    /* Adjust the block address to a linear address */
    blockaddr <<= SD_BLOCKSIZE_NBITS;
    cmd->arg = blockaddr;

    cmd->cmd     = SD_WRITE_BLOCK;
    ctl->rsp_len = SD_WRITE_BLOCK_R;
    if (sd_send_command()) {
      sd_panic_idle(44, 0);
      return FAIL;
    }

    /* Check for an error, like a misaligned write */
    if (cmd->rsp[0] != 0) {
      sd_panic_idle(45, 0);
      return FAIL;
    }

    /* Re-assert CS to continue the transfer */
    SD_CSN = 0;

    /* The write command needs an additional 8 clock cycles before
     * the block write is started.
     */
    tmp = sd_get();
    if (tmp != 0xff)
      sd_panic(46, tmp);

    SD_SPI_CLR_BOTH;
    DMA0SA = (uint16_t) data;
    DMA0DA = (uint16_t) &SD_SPI_TX_BUF;
    DMA0SZ = SD_BLOCKSIZE;
    DMA0CTL = DMA_DT_SINGLE | DMA_SB_DB | DMA_EN |
      DMA_DST_NC | DMA_SRC_INC;
    DMACTL0 = DMA0_TSEL_B0TX;

    /* Send start block token to start the transfer */
    SD_SPI_TX_BUF = SD_TOK_WRITE_STARTBLOCK;
    return SUCCESS;
  }


#ifdef notdef
  const mm_time_t
    sd_busy_max      = {0, 0, .mis = 300};

  const mm_time_t
    sd_small_timeout = {0, 0, .mis = 10};
#endif


  error_t sd_finish_write() {
    uint16_t i;
    uint8_t  tmp;

#ifdef notdef
    /*
     * This needs to get changed for the thread.  need a timeout sequence.
     *
     * We give up to 10 mis for things to settle down.
     *
     * need to convert this timing stuff into using a Timer.
     */
    mm_time_t   t, to, t2;
    time_get_cur(&to);
    add_times(&to, &sd_small_timeout);
#endif

    /*
     * The DMA only kicks out via the transmit path.  Simultaneously
     * we should be getting idles (0xff) coming from the SD card.
     * These are being received resulting in chars being avail in RXBUFF
     * and corresponding Overrun Errors (OE).  Wait for the transmitter
     * to empty.  Then we should have seen the last char received and
     * we can successfully clean out both data avail and the overrun.
     */
    while (SD_SPI_BUSY) {
#ifdef notdef
      /*
       * Need a timeout
       */
      time_get_cur(&t);
      if (time_leq(&to, &t))
	sd_panic(47, 0);
#endif
    }

    tmp = SD_SPI_IFG;
    SD_SPI_CLR_RXINT;
    tmp = SD_SPI_RX_BUF;		/* clean out OE and data avail */

    if (SD_SPI_BUSY)
      sd_panic(48, 0);

    sd_put(0xff);		/* crc ignored */
    sd_put(0xff);

#ifdef notdef
    /*
     * SD should tell us if it accepted the data block
     */
    i=0;
    do {
      tmp = sd_get();
      i++;
      time_get_cur(&t);
    } while ((tmp == 0xFF) && time_leq(&t, &to));
#endif

    i=0;
    do {
      tmp = sd_get();
      i++;
    } while (tmp == 0xFF);

    if ((tmp & 0x0F) != 0x05) {
      i = sd_read_status();
      call Panic.panic(PANIC_MS, 49, tmp, i, 0, 0);
      return FAIL;
    }

    /* wait for the card to go unbusy */
    i = 0;
    while ((tmp = sd_get()) != 0xff) {
      i++;
#ifdef notdef
      if (time_leq(&to, &t))
	sd_panic(50, 0);
#endif
    }
    sd_busy_timeout = i;

    /* Deassert CS */
    SD_CSN = 1;

    /*
     * Send some extra clocks so the card can finish
     * (Where did this come from?)
     */
    sd_start_dma(NULL, NULL, 2);
    sd_wait_dma();

    i = sd_read_status();
    if (i)
      sd_panic(51, i);
    return SUCCESS;
  }


  error_t sd_write_direct(uint32_t blockaddr, uint8_t *data) {
    error_t rtn;

    rtn = sd_start_write(blockaddr, data);
    if (rtn != SUCCESS)
      return rtn;

    /*
     * sd_start_write uses dma0 to sling the data out.
     * just wait for it to finish.
     */

    while (DMA0CTL & DMA_EN)	/* wait for chnn 0 to finish */
      ;
    DMACTL0 = 0;

    /*
     * now that the dma has finished use sd_finish_write to
     * check the result.
     */
    rtn = sd_finish_write();
    return rtn;
  }


  command error_t SDwrite.write[uint8_t cid](uint32_t blockaddr, void *data) {
    if (sd_state) {
      sd_panic_idle(52, sd_state);
      return EBUSY;
    }

    sd_state = SDS_WRITE;
    blk_start = blockaddr;
    data_ptr = data;

    return sd_write_direct(blockaddr, data);
  }


  /*
   * sd_erase
   *
   * erase a contiguous number of blocks
   */

  command error_t SDerase.erase[uint8_t cid](uint32_t blk_s, uint32_t blk_e) {
    sd_cmd_t *cmd;
    sd_ctl_t *ctl;

    if (sd_state) {
      sd_panic_idle(53, sd_state);
      return EBUSY;
    }

    sd_state = SDS_ERASE;
    cur_cid = cid;
    blk_start = blk_s;
    blk_end = blk_e;

    cmd = &sd_cmd;
    ctl = &sd_ctl;
    /*
     * convert blocks into byte addresses.
     */
    blk_start <<= SD_BLOCKSIZE_NBITS;
    blk_end   <<= SD_BLOCKSIZE_NBITS;

    /*
     * send the start and then the end
     */
    cmd->arg = blk_start;
    cmd->cmd     = SD_SET_ERASE_START;
    ctl->rsp_len = SD_SET_ERASE_START_R;
    if (sd_send_command()) {
      sd_panic_idle(54, 0);
      return FAIL;
    }

    /* Check for an error, like a misaligned write */
    if (cmd->rsp[0] != 0) {
      sd_panic_idle(55, cmd->rsp[0]);
      return FAIL;
    }

    cmd->arg = blk_end;
    cmd->cmd     = SD_SET_ERASE_END;
    ctl->rsp_len = SD_SET_ERASE_END_R;
    if (sd_send_command()) {
      sd_panic_idle(56, 0);
      return FAIL;
    }

    /* Check for an error, like a misaligned write */
    if (cmd->rsp[0] != 0) {
      sd_panic_idle(57, cmd->rsp[0]);
      return FAIL;
    }

    cmd->cmd     = SD_ERASE;
    ctl->rsp_len = SD_ERASE_R;
    if (sd_send_command()) {
      sd_panic_idle(58, 0);
      return FAIL;
    }

    /* Check for an error, like a misaligned write */
    if (cmd->rsp[0] != 0) {
      sd_panic_idle(59, cmd->rsp[0]);
      return FAIL;
    }
    return SUCCESS;
  }


#ifdef notdef
  async event void UsciInterrupts.txDone() {
    /*
     * shouldn't ever get here, we never turn intrrupts on for the ADC spi
     *
     * eventually put a panic in here.
     */
  };

  async event void UsciInterrupts.rxDone(uint8_t data) {
    /*
     * shouldn't ever get here, we never turn intrrupts on for the ADC spi
     *
     * eventually put a panic in here.
     */
  };
#endif

  default event void   SDread.readDone[uint8_t cid](uint32_t blk_id, void *buf, error_t error) {}
  default event void SDwrite.writeDone[uint8_t cid](uint32_t blk, void *buf, error_t error) {}
//  default event void SDerase.eraseDone[uint8_t cid](uint32_t blk_start, uint32_t blk_end, error_t error) {}
}
