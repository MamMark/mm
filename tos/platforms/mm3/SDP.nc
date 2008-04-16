/*
 * SD - low level Secure Digital storage driver
 *
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

module SDP {
  provides interface SD;
  uses {
    interface HplMsp430Usart as Usart;
  }
}

implementation {

  noinit sd_cmd_blk_t sd_cmd;
  noinit uint16_t     sd_r1b_timeout;
  noinit uint16_t     sd_rd_timeout;
  noinit uint16_t     sd_wr_timeout;
  noinit uint16_t     sd_reset_timeout;
  noinit uint16_t     sd_busy_timeout;
  noinit bool_t       sd_busyflag;
  noinit uint16_t     sd_reset_idles;

#define SD_PUT_GET_TO 1024
#define U1_OVERRUN (U1RCTL & OE)
#define U1_RX_RDY (IFG2 & URXIFG1)

  void sd_chk_clean(void) {
    uint8_t tmp;

#ifdef SD_PARANOID
    if (call Usart.getUrctl() & OE) {
      call Panic.panic(PANIC_SD, 1, U1RCTL, 0, 0, 0);
      call Usart.setUrctl(call Usart.getUrctl() & ~OE);
    }
    if (call Usart.isRxIntrPending() {
      tmp = call Usart.rx();
      call Panic.panic(PANIC_SD, 2, tmp, 0, 0, 0);
    }
#else
    if (call Usart.getUrctl() & OE)
      call Usart.setUrctl(call Usart.getUrctl() & ~OE);
    if (call Usart.isRxIntrPending() {
      tmp = call Usart.rx();
#endif
  }


  void sd_put(uint8_t tx_data) {
    uint16_t i;

    if (U1_RX_RDY) {
      call Panic.panic(PANIC_SD, 3, 0, 0, 0, 0);
      i = U1RXBUF;
    }

    i = SD_PUT_GET_TO;
    while ( !U1_TX_RDY && i > 0)
      i--;

    if (i == 0)				/* tx timeout */
      call Panic.panic(PANIC_SD, 4, 0, 0, 0, 0);

    U1TXBUF = tx_data;

    i = SD_PUT_GET_TO;
    while ( !U1_RX_RDY && i > 0)
      i--;
    if (i == 0)				/* rx timeout */
      call Panic.panic(PANIC_SD, 5, 0, 0, 0, 0);
    if (U1_OVERRUN)
      call Panic.panic(PANIC_SD, 6, 0, 0, 0, 0);

    /* clean out RX buf and the IFG. */
    tx_data = U1RXBUF;
  }


  uint8_t sd_get(void) {
    uint16_t i;

    if (U1_OVERRUN)
      call Panic.panic(PANIC_SD, 7, 0, 0, 0, 0);
    if (U1_RX_RDY) {
      call Panic.panic(PANIC_SD, 8, 0, 0, 0, 0);
      i = U1RXBUF;
    }

    i = SD_PUT_GET_TO;
    while ( !U1_TX_RDY && i > 0)
      i--;
    if (i == 0)				/* tx timeout */
      call Panic.panic(PANIC_SD, 9, 0, 0, 0, 0);
    U1TXBUF = 0xFF;

    i = SD_PUT_GET_TO;
    while ( !U1_RX_RDY && i > 0)
      i--;

    if (i == 0)				/* rx timeout */
      call Panic.panic(PANIC_SD, 10, 0, 0, 0, 0);

    if (U1_OVERRUN)
      call Panic.panic(PANIC_SD, 11, 0, 0, 0, 0);

    return(U1RXBUF);
  }


  void sd_packarg(sd_cmd_blk_t *cmd, uint32_t value) {
    cmd->arg[0] = (uint8_t) (value >> 24);
    cmd->arg[1] = (uint8_t) (value >> 16);
    cmd->arg[2] = (uint8_t) (value >> 8);
    cmd->arg[3] = (uint8_t) (value);
  }


  int sd_send_cmd55(sd_cmd_blk_t *cmd) {
    uint16_t i;
    uint8_t  tmp;

    sd_put(SD_APP_CMD | 0x40);		/* CMD55 */
    sd_put(0);
    sd_put(0);
    sd_put(0);
    sd_put(0);
    sd_put(0xff);			/* crc, don't care */

    i=0;
    do {
      tmp = sd_get();
      i++;
    } while((tmp > 127) && (i < SD_CMD_TIMEOUT));

    cmd->rsp55 = tmp;
    cmd->stage_count = i;

    if (i >= SD_CMD_TIMEOUT) {
      call Panic.brk();
      return(1);
    }

    tmp = sd_get();		/* finish the command */
    if (tmp != 0xff) {
      call Panic.brk();
      call Panic.panic(PANIC_SD, 12, tmp, 0, 0, 0);
    }

    return(0);
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

  int sd_send_command(sd_cmd_blk_t *cmd) {
    uint16_t i;
    uint16_t rsp_len;
    uint8_t  tmp;

    rsp_len = cmd->rsp_len & RSP_LEN_MASK;
    if (rsp_len != 1 && rsp_len != 2 && rsp_len != 5) {
      call Panic.panic(PANIC_SD, 14, rsp_len, 0, 0, 0);
      return FAIL;
    }
    if (SD_CSN == 0)		// already selected
      call Panic.panic(PANIC_SD, 15, 0, 0, 0, 0);
    sd_chk_clean();

    SD_DESELECT = 0;
    cmd->stage = 1;
    if (cmd->cmd & ACMD_FLAG) {
      tmp = sd_send_cmd55(cmd);
      if (tmp) {
	/* failed, how odd */
	call Panic.brk();
	SD_DESELECT = 1;
	call Panic.panic(PANIC_SD, 16, tmp, 0, 0, 0);
	return(SD_CMD_FAIL);
      }
    } else
      cmd->rsp55 = 0x55;

    cmd->stage = 2;
    sd_put((cmd->cmd & 0x3F) | 0x40);
    i = 0;
    do
      sd_put(cmd->arg[i++]);
    while (i < 4);

    /* This is the CRC. It only matters what we put here for the first
       command. Otherwise, the CRC is ignored for SPI mode unless we
       enable CRC checking. */
    sd_put(0x95);

    /* Wait for a response.  */
    i=0;
    do {
      tmp = sd_get();
      i++;
    } while ((tmp & 0x80) && (i < SD_CMD_TIMEOUT));

    cmd->rsp[0] = tmp;		/* first byte of the response */
    cmd->stage_count = i;

    /* Just bail if we never got a response */
    if (i >= SD_CMD_TIMEOUT) {
      /* stage 2 bail, timeout */
      call Panic.brk();
      SD_DESELECT = 1;
      return(SD_SC_TO_1);
    }

    /* get rest of response if needed */
    i = 1;
    while (i < rsp_len)
      cmd->rsp[i++] = sd_get();

    cmd->stage = 3;
    tmp = sd_get();
    if (tmp != 0xff) {
      call Panic.brk();
      call Panic.panic(PANIC_SD, 17, tmp, 0, 0, 0);
    }

    /* If the response is a "busy" type (R1B), then there's some
     * special handling that needs to be done. The card will
     * output a continuous stream of zeros, so the end of the BUSY
     * state is signaled by any nonzero response. The bus idles
     * high.
     */
    if (cmd->rsp_len & R1B_FLAG) {
      cmd->stage = 4;
      i = 0;
      do {
	i++;
	tmp = sd_get();
      } while (tmp != 0xFF);
      sd_r1b_timeout = i;
      //	cmd->stage_count = i;
      sd_put(0xFF);
    }
    cmd->stage = 0;
    SD_DESELECT = 1;
    return(0);
  }


  /* sd_delay: send idle data while clocking */

  void sd_delay(uint16_t number) {
    uint16_t i;

    for(i = 0; i < number; i++)
      sd_put(0xFF);
  }


  command error_t Init.init() {
    uint8_t i;

    sd_cmd.cmd = 0xf0;
    sd_cmd.rsp_len = 0;
    for (i = 0; i < 4; i++)
      sd_cmd.arg[i] = 0xf0;
    for (i = 0; i < 5; i++)
      sd_cmd.rsp[i] = 0xf0;
    sd_cmd.rsp55 = 0xf0;
    sd_cmd.stage = 0;
    sd_cmd.stage_count = 0;

    sd_r1b_timeout = 0xf0f0;
    sd_rd_timeout = 0xf0f0;
    sd_wr_timeout = 0xf0f0;
    sd_reset_timeout = 0xf0f0;
    sd_busy_timeout = 0xf0f0;
    sd_busyflag = FALSE;
  }


  /* Reset the SD card.
     ret:	    0,	card initilized
     non-zero, error return

     SPI SD initialization sequence:
     CMD0 (reset), CMD55 (app cmd), ACMD41 (app_send_op_cond), CMD58 (send ocr)
  */

  sd_rtn sd_reset(void) {
    uint16_t i;
    sd_cmd_inst_t *ent;

    us1_set_spi_speed(SD_RESET_SPEED);
    ent = &sd_cmd_inst[sd_cmd_inst_idx];
    if (ent->cmd.cmd == SD_FORCE_IDLE)
      ent->rep_count = 0;
    sd_packarg(&sd_cmd, 0);

    /* Clock out at least 74 bits of idles (0xFF).  This allows
       the SD card to complete its power up prior to talking to
       the card.

       When experimenting with different SPI clocks (4M ... 400K) and
       the power up sequence.  ie.

       power off SD
       wait 1 sec
       power on
       set spi speed
       select SD
       sd_reset
       preliminaries
       deselect sd
       sd_delay(100)

       If sd_delay is set to 10 then a power on delay is needed.  The
       amount of delay depends on which SPI clock is used.  Using an
       sd_delay of 100 eliminates the need for the power on delay and
       doesn't appreciably change the reset time which is dominated
       by the GO_OP (A41) time.
    */

    SD_DESELECT = 1;
    sd_delay(SD_RESET_IDLES);

    /* Put the card in the idle state, non-zero return -> error */
    sd_cmd.cmd     = SD_FORCE_IDLE;
    sd_cmd.rsp_len = SD_FORCE_IDLE_R;
    if (sd_send_command(&sd_cmd)) {
      call Panic.panic(PANIC_SD, 19, 0, 0, 0, 0);
      return(SD_CMD_FAIL);
    }


    /* Now wait until the card goes idle. Retry at most SD_IDLE_WAIT_MAX times */
    i = 0;
    do {
      i++;
      sd_cmd.cmd     = SD_GO_OP;
      sd_cmd.rsp_len = SD_GO_OP_R;
      if (sd_send_command(&sd_cmd)) {
	call Panic.panic(PANIC_SD, 20, 0, 0, 0, 0);
	return(SD_CMD_FAIL);
      }
      //    } while ((sd_cmd.rsp[0] & MSK_IDLE) == MSK_IDLE && i < SD_IDLE_WAIT_MAX);
    } while ((sd_cmd.rsp[0] & MSK_IDLE) == MSK_IDLE);
    sd_reset_timeout = i;


    //    if (i >= SD_IDLE_WAIT_MAX)		/* did we bail? */
    //	return(SD_INIT_TIMEOUT);

    sd_cmd.cmd     = SD_SEND_OCR;
    sd_cmd.rsp_len = SD_SEND_OCR_R;
    if (sd_send_command(&sd_cmd)) {
      call Panic.panic(PANIC_SD, 21, 0, 0, 0, 0);
      return(SD_CMD_FAIL);
    }


    /* At a very minimum, we must allow 3.3V. */
    if ((sd_cmd.rsp[2] & MSK_OCR_33) != MSK_OCR_33)
      return(SD_BAD_PWR);

    /* Set the block length */
    if (sd_set_blocklen(&sd_cmd, SD_BLOCKSIZE)) {
      call Panic.panic(PANIC_SD, 22, 0, 0, 0, 0);
      return(SD_CMD_FAIL);
    }

    /* If we got this far, initialization was OK. */
    us1_set_spi_speed(SD_SPI_SPEED);
    return(SD_OK);
  }


  /*
   * sd_read_data_direct: read data from the SD after sending a command
   *    does not use dma and waits for the data.
   */

  static sd_rtn
    sd_read_data_direct(sd_cmd_blk_t *cmd, uint16_t data_len, uint8_t *data) {
    uint16_t i;
    uint8_t  tmp;

    if (cmd == NULL) {
      call Panic.panic(PANIC_SD, 23, 0, 0, 0, 0);
      return(SD_CMD_FAIL);
    }
    sd_wait_notbusy();
    if (sd_send_command(cmd)) {
      call Panic.panic(PANIC_SD, 24, 0, 0, 0, 0);
      return(SD_CMD_FAIL);
    }

    /* Check for an error, like a misaligned read */
    if (cmd->rsp[0] != 0) {
      call Panic.panic(PANIC_SD, 25, 0, 0, 0, 0);
      return(SD_BAD_RESPONSE);
    }
    /* Re-assert CS to continue the transfer */
    SD_DESELECT = 0;

    /* Wait for the token */
    i=0;
    do {
      tmp = sd_get();
      i++;
    } while ((tmp == 0xFF) && i < SD_READ_TIMEOUT);
    sd_cmd_inst[sd_cmd_inst_idx].aux_rsp = tmp;
    sd_rd_timeout = i;

    if ((tmp & MSK_TOK_DATAERROR) == 0 || i >= SD_READ_TIMEOUT) {
      /*
       * Clock out a byte before returning, let SD finish
       * what is this based on?
       */
      sd_put(0xFF);

      /* The card returned an error, or timed out. */
      return(SD_READ_ERR);
    }

    for (i = 0; i < data_len; i++)
      data[i] = sd_get();

    /* Ignore the CRC */
    sd_get();
    sd_get();

    SD_DESELECT = 1;
    /* Send some extra clocks so the card can finish */
    sd_delay(2);

    return(SD_OK);
  }


  /* sd_check_crc
   *
   * i: data	pointer to a 512 byte + 2 bytes of CRC at end (514)
   *
   * o: rtn	0 if crc is okay
   *		1 crc didn't check.
   */

  int
    sd_check_crc(uint8_t *data, uint16_t len, uint16_t crc) {
    return(0);
  }


  /* sd_compute_crc
   *
   * append a crc computed over the data buffer pointed at by data
   *
   * i: data	ptr to 512 bytes of data (with 2 additional bytes available
   *		at the end for the crc (total size 514).
   * o: none
   */

  void
    sd_compute_crc(uint8_t *data) {
    //    data[512] = 0;
    //    data[513] = 0;
  }


  /*
   * sd_read_data_dma: read data from the SD after sending a command
   */

  static sd_rtn
    sd_read_data_dma(sd_cmd_blk_t *cmd, uint16_t data_len, uint8_t *data) {
    uint16_t i, crc;
    uint8_t  tmp, idle_byte;

    if (cmd == NULL)
      cmd = &sd_cmd;
    if (sd_send_command(cmd))
      return(SD_CMD_FAIL);

    /* Check for an error, like a misaligned read */
    if (cmd->rsp[0] != 0) {
      call Panic.panic(PANIC_SD, 26, 0, 0, 0, 0);
      return(SD_BAD_RESPONSE);
    }

    /* Re-assert CS to continue the transfer */
    SD_DESELECT = 0;

    /* Wait for the token */
    i=0;
    do {
      tmp = sd_get();
      i++;
    } while ((tmp == 0xFF) && i < SD_READ_TIMEOUT);
    sd_cmd_inst[sd_cmd_inst_idx].aux_rsp = tmp;
    sd_rd_timeout = i;

    if ((tmp & MSK_TOK_DATAERROR) == 0 || i >= SD_READ_TIMEOUT) {
      /* Clock out a byte before returning, let SD finish */
      sd_put(0xFF);

      /* The card returned an error, or timed out. */
      return(SD_READ_ERR);
    }

    idle_byte = 0xff;
    U1IFG &= ~(URXIFG1 | UTXIFG1);

    DMA0SA  = (uint16_t) &U1RXBUF;
    DMA0DA  = (uint16_t) data;
    DMA0SZ  = data_len;
    DMA0CTL = DMA_DT_SINGLE | DMA_SB_DB | DMA_EN |
      DMA_DST_INC | DMA_SRC_NC;

    DMA1SA  = (uint16_t) &idle_byte;
    DMA1DA  = (uint16_t) &U1TXBUF;
    DMA1SZ  = data_len - 1;
    DMA1CTL = DMA_DT_SINGLE | DMA_SB_DB | DMA_EN |
      DMA_DST_NC | DMA_SRC_NC;

    DMACTL0 = DMA1_TSEL_U1RX | DMA0_TSEL_U1RX;
    U1TXBUF = 0xff;

    while (DMA0CTL & DMA_EN)	/* wait for chn 0 to finish */
      ;

    DMACTL0 = 0;

    crc = sd_get();
    crc = crc << 8;
    crc |= sd_get();

    /* Deassert CS */
    SD_DESELECT = 1;
    /* Send some extra clocks so the card can finish */
    sd_delay(2);
    if (sd_check_crc(data, data_len, crc)) {
      call Panic.panic(PANIC_SD, 27, 0, 0, 0, 0);
      return(SD_CRC_FAIL);
    }

    return(SD_OK);
  }


  void
    sd_display_ocr(void *data) {
    uint8_t *ocr;

    ocr = data;
    __cradle_printf("OCR REGISTER CONTENTS");
    __cradle_printf("\nOCR: %02x%02x%02x%02x\n\n\n", ocr[0], ocr[1], ocr[2], ocr[3]);
  }


  sd_rtn
    sd_read_csd(sd_cmd_blk_t *cmd, uint8_t *data) {
    if (cmd == NULL)
      cmd = &sd_cmd;
    cmd->cmd     = SD_SEND_CSD;
    cmd->rsp_len = SD_SEND_CSD_R;
    return(sd_read_data_direct(cmd, SD_CSD_LEN, data));
  }


  void
    sd_display_csd(void *data) {
    sd_csd_t *csdp;

    csdp = data;
    __cradle_printf("CSD REGISTER CONTENTS\n");
    __cradle_printf("CSD_STRUCT: %0x\n", csdp->csd_struct);
    __cradle_printf("\nRSVD1: %0x\n", csdp->rsvd1);
    __cradle_printf("TAAC: %0x\n", csdp->taac);   
    __cradle_printf("NSAC: %0x\n", csdp->nsac);
    __cradle_printf("Trans Speed: %0x\n", csdp->tran_speed);
    __cradle_printf("Card Com. Class: %0x%0x\n", csdp->ccc_high,
		    csdp->ccc_low);
    __cradle_printf("Read Block Len: %0x\n", csdp->rd_bl_len);
    __cradle_printf("Read Blk Part: %0x\n", csdp->rd_bl_partial);
    __cradle_printf("Wrt Blk Misall: %0x\n", csdp->wt_bl_misall);
    __cradle_printf("Read Blk Misall: %0x\n", csdp->rd_bl_misall);
    __cradle_printf("DSR_IMP: %0x\n", csdp->dsr_imp);
    __cradle_printf("RSVD2: %0x\n", csdp->rsvd2);
    __cradle_printf("Csize: %0x\n", csdp->csize_high<<10 + 
		    csdp->csize_mid<<2 + csdp->csize_low);
    __cradle_printf("Vdd Min Read Curr: %0x\n", csdp->vdd_min_rd_curr);
    __cradle_printf("Vdd Max Read Curr: %0x\n", csdp->vdd_max_rd_curr);
    __cradle_printf("Vdd Min Write Curr: %0x\n", csdp->vdd_min_w_curr);   
    __cradle_printf("Vdd Max Write Curr: %0x\n", csdp->vdd_max_w_curr);
    __cradle_printf("Csize Mult: %0x%0x\n", csdp->csize_mlt_high, 
		    csdp->csize_mlt_low);
    __cradle_printf("Erase Blk Enble: %0x\n", csdp->erase_blk_enable);
    __cradle_printf("Sector Size: %0x%0x\n", csdp->sect_size_high,
		    csdp->sect_size_low);
    __cradle_printf("WRT Prot GRPSize: %0x\n", csdp->grp_size);
    __cradle_printf("Write Prot. Grp Enble: %0x\n", csdp->wp_grp_enable);
    __cradle_printf("Rsvd3: %0x\n", csdp->rsvd3);
    __cradle_printf("Write Spd Factor: %0x\n", csdp->wt_spd_fact);
    __cradle_printf("Write Blk Len: %0x%0x\n", csdp->wt_blk_len_high,
		    csdp->wt_blk_len_low);
    __cradle_printf("Write Blk Partial: %0x\n", csdp->wt_blk_partial);
    __cradle_printf("Rsvd4: %0x\n", csdp->rsvd4);
    __cradle_printf("File Format GRP: %0x\n", csdp->file_form_grp);
    __cradle_printf("Copy: %0x\n", csdp->copy);
    __cradle_printf("Perm Wrt Prot.: %0x\n", csdp->perm_wt_prot);
    __cradle_printf("Temp Wrt Prot.: %0x\n", csdp->tmp_wt_prot); 
    __cradle_printf("File Format: %0x\n", csdp->file_format);
    __cradle_printf("Rsvd5: %0x\n", csdp->rsvd5);
    __cradle_printf("CRC: %0x\n", csdp->crc); 
    __cradle_printf("AlwaysONE: %0x\n\n\n", csdp->alwaysONE);  

  }


  sd_rtn
    sd_read_cid(sd_cmd_blk_t *cmd, uint8_t *data) {
    if (cmd == NULL)
      cmd = &sd_cmd;
    cmd->cmd     = SD_SEND_CID;
    cmd->rsp_len = SD_SEND_CID_R;
    return(sd_read_data_direct(cmd, SD_CID_LEN, data));
  }


  void
    sd_display_cid(void *data) {
    sd_cid_t *cidp;

    cidp = data;
    __cradle_printf("CID REGISTER CONTENTS");
    __cradle_printf("Id: Mfg: %02x  OEM: %02x%02x\n", cidp->mid, 
                    cidp->oid[0], cidp->oid[1]);
    __cradle_printf("Prod Name: %02x%02x%02x%02x%02x  Rev: %02x\n", cidp->pnm[0],
		    cidp->pnm[1], cidp->pnm[2], cidp->pnm[3],
		    cidp->pnm[4], cidp->prv);
    __cradle_printf("Serial Num: %02x%02x%02x%02x  rsvd: %x\n",
		    cidp->psn[0], cidp->psn[1], cidp->psn[2], cidp->psn[3],
		    cidp->rsvd);
    __cradle_printf("built:  %d/%d  (%0x%0x %0x%0x)  last: %02x\n\n\n",
		    cidp->mdt_m, (2000 + cidp->mdt_y1*10 + cidp->mdt_y0),
		    cidp->rsvd, cidp->mdt_y1, cidp->mdt_y0, cidp->mdt_m,
		    cidp->last);
  }


  uint16_t
    sd_read_status(sd_cmd_blk_t *cmd) {
    uint16_t i;

    if (cmd == NULL)
      cmd = &sd_cmd;
    cmd->cmd     = SD_SEND_STATUS;
    cmd->rsp_len = SD_SEND_STATUS_R;
    if (sd_send_command(cmd))
      return(0xffff);
    i = (cmd->rsp[0] << 8) | cmd->rsp[1];
    return(i);
  }

  void
    sd_display_status(void *data) {
    sd_status_t *statusp;
   
    statusp = data;
    __cradle_printf("SD STATUS REGISTER CONTENTS");
    __cradle_printf("AlwaysZERO: 0x\n", statusp->alwaysZero);
    __cradle_printf("Paremeter Error: 0x\n", statusp->param_err);
    __cradle_printf("Address Error: 0x\n", statusp->address_err);
    __cradle_printf("Erase Seq. Error: 0x\n", statusp->erase_seq_err);
    __cradle_printf("Command CRC Error: 0x\n", statusp->com_crc_err);
    __cradle_printf("Illegal Command.: 0x\n", statusp->illeg_com);
    __cradle_printf("Erase Reset: 0x\n", statusp->erase_rst);
    __cradle_printf("Idle State: 0x\n", statusp->idle_state);
    __cradle_printf("Out of Range CSD overwrt: 0x\n", 
		    statusp->out_rge_csd_ovrwt);
    __cradle_printf("Erase Param: 0x\n", statusp->erase_param);
    __cradle_printf("WP Violation: 0x\n", statusp->wp_violation);
    __cradle_printf("Card Ecc Fail: 0x\n", statusp->card_ecc_fail);
    __cradle_printf("CC Error: 0x\n", statusp->cc_error);
    __cradle_printf("Error: 0x\n", statusp->error);
    __cradle_printf("WP Erase Skip: 0x\n", statusp->wp_erase_skip);
    __cradle_printf("Card is Locked: 0x\n\n\n", statusp->card_is_locked);
  }

  sd_rtn
    sd_read_scs(sd_cmd_blk_t *cmd, uint8_t *data) {
    if (cmd == NULL)
      cmd = &sd_cmd;
    cmd->cmd     = SD_SEND_SCS;
    cmd->rsp_len = SD_SEND_SCS_R;
    return(sd_read_data_direct(cmd, SD_SCS_LEN, data));
  }


  void
    sd_display_scs(void *data) {
    sd_scs_t *scsp;
 
    int i = 0;
    scsp = data;
    __cradle_printf("SCR Register Contents");
    __cradle_printf("SCS Data Bus Width: %0x\n", scsp->data_bus_width);
    __cradle_printf("Secured Mode: %0x\n", scsp->secured_mode);
    __cradle_printf("SD Card Type: %0x\n", scsp->sd_card_type);
    __cradle_printf("Size of Prot. Area: %0x\n", scsp->size_prot_area);
    
    __cradle_printf("The Rest: ");
    for (i=0; i < 56; i++) {
      __cradle_printf("%02x ", scsp->the_rest[i]);
    }
    __cradle_printf("/n/n");
  } 

  sd_rtn
    sd_read_scr(sd_cmd_blk_t *cmd, uint8_t *data) {
    if (cmd == NULL)
      cmd = &sd_cmd;
    cmd->cmd     = SD_SEND_SCR;
    cmd->rsp_len = SD_SEND_SCR_R;
    return(sd_read_data_direct(cmd, SD_SCR_LEN, data));
  }


  void
    sd_display_scr(void *data) {
    sd_scr_t *scrp;

    scrp = data;
    __cradle_printf("SCR REGISTER CONTENTS");
    __cradle_printf("Version # of SCR struct: 0x\n", scrp->scr_struct);
    __cradle_printf("SD CARD-Spec. Version: %0x\n", scrp->scr_spec);
    __cradle_printf("Data Status after erase: %0x\n", scrp->d_stat_after_erase);    
    __cradle_printf("SD Security Algoritm: %0x\n", scrp->sd_security);    
    __cradle_printf("Supported DAT bus Widths: %0x\n\n\n", scrp->sd_bus_widths);    
  }


  /*
   * Display Card Data
   *
   * read and dump out intrinsic card data from an SD card
   */

  void sd_display_card(void *dp) {
    uint16_t tmp;

    sd_read_cid(NULL, dp);
    sd_display_cid(dp);

    sd_cmd.cmd     = SD_SEND_OCR;
    sd_cmd.rsp_len = SD_SEND_OCR_R;
    if (sd_send_command(&sd_cmd))
      call Panic.panic(PANIC_SD, 28, 0, 0, 0, 0);
    sd_display_ocr(&sd_cmd.rsp[1]);

    sd_read_csd(NULL, dp);
    sd_display_csd(dp);

    tmp = sd_read_status(NULL);
    __cradle_printf("\nStatus: %04x\n", tmp);

    sd_read_scr(NULL, dp);
    sd_read_scs(NULL, dp);
  }


  /* sd_read_block: read a 512 byte block from the SD

  input:  cmd		pointer to cmd block
  blockaddr	block to read.  (max 23 bits)
  data		pointer to data buffer
  output: rtn		0 call successful, err otherwise
  */

  sd_rtn sd_read_block(uint32_t blockaddr, uint8_t *data) {
    sd_cmd_blk_t *cmd;

    cmd = &sd_cmd;
    /* Adjust the block address to a linear address */
    blockaddr <<= SD_BLOCKSIZE_NBITS;

    /* Pack the address */
    sd_packarg(cmd, blockaddr);

    /* Need to add size checking, 0 = success */
    cmd->cmd     = SD_READ_BLOCK;
    cmd->rsp_len = SD_READ_BLOCK_R;
    return(sd_read_data_dma(cmd, SD_BLOCKSIZE, data));
  }


  /* sd_read8
   *
   * read a buffer from the SD that is 8 only long.  Used for
   * looking at the 1st 8 bytes of each sector.
   *
   * Assumes that a sd_set_blocklen(8) has been executed.  After
   * the user is done with reading 1st 8 make sure you reset
   * the blocklen back to 512.  Otherwise things get weird.  (timeouts)
   */

  sd_rtn sd_read8(sd_cmd_blk_t *cmd, uint32_t blockaddr, uint8_t *data) {
    if (cmd == NULL)
      cmd = &sd_cmd;
    /* Adjust the block address to a linear address */
    blockaddr <<= SD_BLOCKSIZE_NBITS;

    /* Pack the address */
    sd_packarg(cmd, blockaddr);

    /* Need to add size checking, 0 = success */
    cmd->cmd     = SD_READ_BLOCK;
    cmd->rsp_len = SD_READ_BLOCK_R;
    return(sd_read_data_direct(cmd, 8, data));
  }


  /*
   * Start a write to the SD card using DMA.
   *
   * Clears DMA Int Enable.
   */

  sd_rtn sd_start_write(sd_cmd_blk_t *cmd, uint32_t blockaddr, uint8_t *data) {
    uint8_t  tmp;

    if (cmd == NULL)
      cmd = &sd_cmd;
    sd_compute_crc(data);
    /* Adjust the block address to a linear address */
    blockaddr <<= SD_BLOCKSIZE_NBITS;

    /* Pack the address */
    sd_packarg(cmd, blockaddr);

    cmd->cmd     = SD_WRITE_BLOCK;
    cmd->rsp_len = SD_WRITE_BLOCK_R;
    if (sd_send_command(cmd)) {
      call Panic.panic(PANIC_SD, 30, 0, 0, 0, 0);
      return(SD_CMD_FAIL);
    }

    /* Check for an error, like a misaligned write */
    if (cmd->rsp[0] != 0) {
      call Panic.panic(PANIC_SD, 31, 0, 0, 0, 0);
      return(SD_BAD_RESPONSE);
    }

    /* Re-assert CS to continue the transfer */
    SD_DESELECT = 0;

    /* The write command needs an additional 8 clock cycles before
     * the block write is started. */
    tmp = sd_get();
    sd_cmd_inst[sd_cmd_inst_idx].aux_rsp = tmp;
    if (tmp != 0xff)
      call Panic.panic(PANIC_SD, 32, tmp, 0, 0, 0);

    U1IFG = ~(URXIFG1 | UTXIFG1);
    DMA0SA = (uint16_t) data;
    DMA0DA = (uint16_t) &U1TXBUF;
    DMA0SZ = SD_BLOCKSIZE;
    DMA0CTL = DMA_DT_SINGLE | DMA_SB_DB | DMA_EN |
      DMA_DST_NC | DMA_SRC_INC;
    DMACTL0 = DMA0_TSEL_U1TX;

    /* Send start block token to start the transfer */
    U1TXBUF = SD_TOK_WRITE_STARTBLOCK;
    return(SD_OK);
  }


  const mm_time_t
    sd_busy_max      = {0, 0, .mis = 300};

  const mm_time_t
    sd_small_timeout = {0, 0, .mis = 10};


  error_t sd_finish_write(void) {
    uint16_t i;
    uint8_t  tmp;
    mm_time_t   t, to, t2;

    /*
     * We give up to 10 mis for things to settle down.
     */
    time_get_cur(&to);
    add_times(&to, &sd_small_timeout);

    /*
     * The DMA only kicks out via the transmit path.  Simultaneously
     * we should be getting idles (0xff) coming from the SD card.
     * These are being received resulting in chars being avail in RXBUFF
     * and corresponding Overrun Errors (OE).  Wait for the transmitter
     * to empty.  Then we should have seen the last char received and
     * we can successfully clean out both data avail and the overrun.
     */
    while (!U1_TX_EMPTY) {
      time_get_cur(&t);
      if (time_leq(&to, &t))
	call Panic.panic(PANIC_SD, 41, 0, 0, 0, 0);
    }

    tmp = U1IFG;
    tmp = U1RXBUF;		/* clean out OE and data avail */

    if (!U1_TX_EMPTY || U1_RX_RDY)
      call Panic.panic(PANIC_SD, 33, 0, 0, 0, 0);

    sd_put(0);			/* crc ignored */
    sd_put(0);

    /*
     * SD should tell us if it accepted the data block
     */
    i=0;
    do {
      tmp = sd_get();
      i++;
      time_get_cur(&t);
    } while ((tmp == 0xFF) && time_leq(&t, &to));
    sd_cmd_inst[sd_cmd_inst_idx].aux_rsp = tmp;
    if ((tmp & 0x0F) != 0x05) {
      i = sd_read_status(NULL);
      call Panic.panic(PANIC_SD, 34, tmp, i, 0, 0);
      return(SD_WRITE_ERR);
    }

    /* wait for the card to go unbusy */
    time_get_cur(&to);
    t2 = to;
    add_times(&to, &sd_busy_max);
    i = 0;
    while ((tmp = sd_get()) != 0xFF) {
      i++;
      time_get_cur(&t);
      if (time_leq(&to, &t))
	call Panic.panic(PANIC_SD, 42, 0, 0, 0, 0);
    }
    sd_busy_timeout = i;
    time_get_cur(&t);

    /* Deassert CS */
    SD_DESELECT = 1;

    /*
     * Send some extra clocks so the card can finish
     * (Where did this come from?)
     */
    sd_delay(2);

    i = sd_read_status(NULL);
    if (i)
      call Panic.panic(PANIC_SD, 128, i, 0, 0, 0);
    return SUCCESS;
  }


  sd_rtn sd_write_block(sd_cmd_blk_t *cmd, uint32_t blockaddr, uint8_t *data) {
    sd_rtn  rtn;

    rtn = sd_start_write(cmd, blockaddr, data);
    if (rtn != SD_OK)
      return(rtn);

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
    return(rtn);
  }


  /*
    sd_wait_notbusy: make sure card isn't busy

    synchronously waits until any pending block transfers
    are finished.

    Note that sd_read_block() and sd_write_block() already call this
    function internally before attempting a new transfer, so there are
    only two times when a user would need to use this function.
    1) When the processor will be shutting down. All pending
    writes should be finished first.   And 2) When the user needs the
    results of an sd_read_block() call right away.
  */

  void sd_wait_notbusy(void) {
    uint16_t i;

    /* Check for the busy flag (set on a write block) */
    if (sd_busyflag) {
      i = 0;
      while (sd_get() != 0xFF)
	i++;
      sd_busyflag = FALSE;
      sd_busy_timeout = i;
    }

    /* Deassert CS */
    SD_DESELECT = 1;
    /* Send some extra clocks so the card can finish */
    sd_delay(2);
  }


#ifdef notdef
  /*
   * sd_erase
   *
   * erase a contiguous number of blocks
   */

  sd_rtn
    sd_erase(sd_cmd_blk_t *cmd, uint32_t blk_start, uint32_t blk_end) {

    if (cmd == NULL)
      cmd = &sd_cmd;
    /*
     * convert blocks into byte addresses.
     */
    blk_start <<= SD_BLOCKSIZE_NBITS;
    blk_end   <<= SD_BLOCKSIZE_NBITS;

    /*
     * send the start and then the end
     */
    sd_packarg(cmd, blk_start);
    cmd->cmd     = SD_SET_ERASE_START;
    cmd->rsp_len = SD_SET_ERASE_START_R;
    if (sd_send_command(cmd)) {
      call Panic.panic(PANIC_SD, 35, 0, 0, 0, 0);
      return(SD_INTERNAL);
    }

    /* Check for an error, like a misaligned write */
    if (cmd->rsp[0] != 0) {
      call Panic.panic(PANIC_SD, 36, cmd->rsp[0], 0, 0, 0);
      return(SD_INTERNAL);
    }

    sd_packarg(cmd, blk_end);
    cmd->cmd     = SD_SET_ERASE_END;
    cmd->rsp_len = SD_SET_ERASE_END_R;
    if (sd_send_command(cmd)) {
      call Panic.panic(PANIC_SD, 37, 0, 0, 0, 0);
      return(SD_INTERNAL);
    }

    /* Check for an error, like a misaligned write */
    if (cmd->rsp[0] != 0) {
      call Panic.panic(PANIC_SD, 38, cmd->rsp[0], 0, 0, 0);
      return(SD_INTERNAL);
    }

    cmd->cmd     = SD_ERASE;
    cmd->rsp_len = SD_ERASE_R;
    if (sd_send_command(cmd)) {
      call Panic.panic(PANIC_SD, 39, 0, 0, 0, 0);
      return(SD_INTERNAL);
    }

    /* Check for an error, like a misaligned write */
    if (cmd->rsp[0] != 0) {
      call Panic.panic(PANIC_SD, 40, cmd->rsp[0], 0, 0, 0);
      return(SD_INTERNAL);
    }
    return(SD_OK);
  }
#endif

}
