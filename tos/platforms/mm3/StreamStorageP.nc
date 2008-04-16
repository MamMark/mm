/*
 * StreamStorage.nc - stream storage based on contiguous
 * blocks on a FAT32 filesystem.  Ported to TinyOS 2.x
 *
 * Block 0 of the SD is the MBR.  If the filesystem is
 * bootable then most of this block (512 bytes) is code
 * that boot straps the system.  The SD card we are using
 * is not bootable.  So we lay a record down in the middle
 * of the MBR identified by majik numbers that tells us
 * the absolute block numbers of the data areas.  These
 * areas have been built by special tools that allocate
 * according to FAT rules files that encompass these regions.
 * That way the actual data files can be accessed directly
 * from any system that understands the FAT filesystem.  No
 * special tools are needed.  This greatly eases the accessibility
 * of the resultant data on Winbloz machines (which unfortunately
 * need to be supported for post processing data).
 *
 * Anyway.  StreamStorage provides a simple handle based write
 * interface.  StreamStorage provides a pool of buffers and
 * manages when the buffers get written to the SD.
 *
 * Copyright 2008 Eric B. Decker
 * Mam-Mark Project
 *
 * Based on ms_sd.c - Stream Storage Interface - SD direct interface
 * Copyright 2006-2007, Eric B. Decker
 * Mam-Mark Project
 */

#include "stream_storage.h"

/*
 * These macros are used to ConvertFrom_LittleEndian to the native
 * format of the machine this code is running on.  The Data Block
 * Locator (the block of information in the MBR that tells us where
 * our data areas live) is written in little endian order because most
 * machines in existence (thanks Intel) are little endian.
 *
 * The MSP430 is little endian so these macros do nothing.  If a machine
 * is big endian they would have to do byte swapping.
 */

#define CF_LE_16(v) (v)
#define CF_LE_32(v) (v)
#define CT_LE_16(v) (v)
#define CT_LE_32(v) (v)


module StreamStorageP {
  provides {
    interface Init;
    interface SplitControl as SSControl;
    interface StreamStorage as SS;
  }
}
  
implementation {

  noinit ss_handle_t ss_handles[SS_NUM_BUFS];
  noinit ss_control_t ssc;

  command error_t Init.init {
    dblk_loc_t *dbl;
    uint32_t   lower, blk, upper;
    uint16_t i;
    uint8_t *dp;

    ssc.majik_a  = SSC_MAJIK_A;

    ssc.ss_state = SS_STATE_UNINITILIZED;
    ssc.alloc_index = 0;
    ssc.in_index    = 0;
    ssc.out_index   = 0;
    ssc.num_full    = 0;
    ssc.max_full    = 0;

    ssc.panic_start = ssc.panic_end = 0;
    ssc.config_start = ssc.config_end = 0;
    ssc.dblk_start = ssc.dblk_end = 0;
    ssc.dblk_nxt = 0;

    ssc.majik_b = SSC_MAJIK_B;

    for (i = 0; i < SS_NUM_BUFS; i++) {
      ss_handles[i].majik     = SS_BUF_MAJIK;
      ss_handles[i].buf_state = SS_BUF_STATE_FREE;
    }
  }


  /*
   * blk_empty
   *
   * check if a Stream storage data block is empty.
   * Currently, an empty (erased SD data block) looks like
   * it is zeroed.  So we look for all data being zero.
   */

  int
  blk_empty(uint8_t *buf) {
    uint16_t i;
    uint16_t *ptr;

    ptr = (void *) buf;
    for (i = 0; i < SD_BLOCKSIZE/2; i++)
      if (ptr[i])
	return(0);
    //    return(1);
    return(0);
  }


  /*
   * check_dblk_loc
   *
   * Check the Dblk Locator for validity.
   *
   * First, we look for the magic number in the majik spot
   * Second, we need the checksum to match.  Checksum is computed over
   * the entire dblk_loc structure.
   *
   * i: *dbl	dblk locator structure pointer
   *
   * o: rtn	0  if dblk valid
   *		1  if no dblk found
   *		2  if dblk checksum failed
   *		3  bad value in dblk
   */

  uint16_t
  check_dblk_loc(dblk_loc_t *dbl) {
    uint16_t *p;
    uint16_t sum, i;

    if (dbl->sig != CT_LE_32(TAG_DBLK_SIG))
      return(1);
    if (dbl->panic_start == 0 || dbl->panic_end == 0 ||
	dbl->config_start == 0 || dbl->config_end == 0 ||
	dbl->dblk_start == 0 || dbl->dblk_end == 0)
      return(3);
    if (dbl->panic_start > dbl->panic_end ||
	dbl->config_start > dbl->config_end ||
	dbl->dblk_start > dbl->dblk_end)
      return(3);
    p = (void *) dbl;
    sum = 0;
    for (i = 0; i < DBLK_LOC_SIZE_SHORTS; i++)
      sum += CF_LE_16(p[i]);
    if (sum)
      return(2);
    return(0);
  }

  error_t
  read_blk(uint32_t blk_id, void *buf) {
    error_t err;
    uint8_t *dp;

    err = call SD.read_block(blk_id, buf);

    /*
     * sometimes.  not sure of the conditions.  When using dma
     * the first byte will show up as 0xfe (something having
     * to do with the cmd response).  Check for this and if seen
     * flag it and re-read the buffer
     */
    dp = buf;
    if (dp[0] == 0xfe) {
      call Panic.brk();
      read_blk_fail(blk_id, buf);
    }

    return((ss_rtn) err);
  }

  error_t
  read_blk_fail(uint32_t blk_id, void *buf) {
    ss_rtn err;

    err = call SD.read_blk(blk_id, buf);
    if (err) {
      call Panic.panic(PANIC_SS, 7, err, 0, 0, 0);
      return FAIL;
    }
    return err;
  }


  command error_t SSControl.start() {
    error_t err;

    call HW.sd_pwr_on();
    err = call SD.reset();
    if (err) {
      call Panic.panic(PANIC_SS, 1, err, 0, 0, 0);
      return err;
    }

    dp = ss_handles[0].buf;
    err = call SD.read_blk(0, dp);
    if (err) {
      call Panic.panic(PANIC_SS, 1, err, 0, 0, 0);
      return err;
    }

    dbl = (void *) ((uint8_t *) dp + DBLK_LOC_OFFSET);

#ifdef notdef
    if (do_test)
      sd_display_card(dp);
#endif

    if (check_dblk_loc(dbl)) {
      call Panic.panic(PANIC_SS, 2, 0, 0, 0, 0);
      return FAIL;
    }

    ssc.panic_start  = CF_LE_32(dbl->panic_start);
    ssc.panic_end    = CF_LE_32(dbl->panic_end);
    ssc.config_start = CF_LE_32(dbl->config_start);
    ssc.config_end   = CF_LE_32(dbl->config_end);
    ssc.dblk_start   = CF_LE_32(dbl->dblk_start);
    ssc.dblk_end     = CF_LE_32(dbl->dblk_end);

    err = SD.read_blk(ssc.dblk_start, dp);
    if (err) {
      call Panic.panic(PANIC_SS, 2, err, 0, 0, 0);
      return err;
    }
    if (blk_empty(dp)) {
      ssc.dblk_nxt = ssc.dblk_start;
      return SUCCES;
    }

    lower = ssc.dblk_start;
    upper = ssc.dblk_end;
    empty = 0;

    while (lower < upper) {
      blk = (upper - lower)/2 + lower;
      if (blk == lower)
	blk = lower = upper;
      ss_read_blk_fail(blk, dp);
      if (blk_empty(dp)) {
	upper = blk;
	empty = 1;
      } else {
	lower = blk;
	empty = 0;
      }
    }

#ifdef notdef
    if (do_test) {
      ssc.dblk_nxt = ssc.dblk_start;
      ss_test();
    }
#endif

    call HW.sd_pwr_off();

    /* for now force to always hit the start. */
    empty = 1; blk = ssc.dblk_start;
    if (empty) {
      ssc.dblk_nxt = blk;
      return SUCCESS;
    }

    call Panic.panic(PANIC_SS, 3, 0, 0, 0, 0);
    return FAIL;
  }


  command ss_handle_t* get_free_handle() {
    ss_handle_t *sshp;

    if (ssc.alloc_index >= SS_NUM_BUFS || ssc.majik_a != SSC_MAJIK_A ||
	ssc.majik_b != SSC_MAJIK_B ||
	ss_handles[ssc.alloc_index].buf_state < SS_BUF_STATE_FREE ||
	ss_handles[ssc.alloc_index].buf_state >= SS_BUF_STATE_MAX) {
      call Panic.panic(PANIC_SS, 4, 0, 0, 0, 0);
      return NULL;
    }

    if (ss_handles[ssc.alloc_index].buf_state == SS_BUF_STATE_FREE) {
      if (ss_handles[ssc.alloc_index].majik != SS_BUF_MAJIK) {
	call Panic.panic(PANIC_SS, 5, 0, 0, 0, 0);
	return NULL;
      }
      ss_handles[ssc.alloc_index].buf_state = SS_BUF_STATE_ALLOC;
      sshp = ss_handles[ssc.alloc_index];
      ssc.alloc_index++;
      if (ssc.alloc_index >= SS_NUM_BUFS)
	ssc.alloc_index = 0;
      return sshp;
    }
    call Panic.panic(PANIC_SS, 6, 0, 0, 0, 0);
    return NULL;
  }

  command uint8_t *handle_to_buf(ss_handle_t *handle) {
  }

void
ss_machine(msg_event_t *msg) {
    uint8_t     *buf;
    ss_handle_t	*ss_handle;
    ss_timer_data_t mtd;
    mm_time_t       t;
    sd_rtn	 err;

    buf = (uint8_t *) (msg->msg_param);

    if (ssc.majik_a != SSC_MAJIK_A || ssc.majik_b != SSC_MAJIK_B)
	call Panic.panic(PANIC_SS, 10, ssc.majik_a, ssc.majik_b, 0, 0);

    if (ssc.ss_state < SS_STATE_OFF || ssc.ss_state >= SS_STATE_MAX)
	call Panic.panic(PANIC_SS, 11, ssc.ss_state, 0, 0, 0);

    if (msg->msg_addr != MSG_ADDR_MS)
	call Panic.panic(PANIC_SS, 12, msg->msg_addr, 0, 0, 0);

    switch(ssc.ss_state) {
      case SS_STATE_OFF:
      case SS_STATE_IDLE:
	  /*
	   * Only expected message is Buffer_Full.  Others
	   * are weird.
	   */
	  if (msg->msg_id != msg_ss_Buffer_Full)
	      call Panic.panic(PANIC_SS, 13, msg->msg_id, 0, 0, 0);

	  /*
	   * back up to get the full handle.  The buffer
	   * coming back via the buffer_full msg had better
	   * be allocated as well as the next one we expect.
	   * Next one expected is ssc.in_index.
	   */
	  ss_handle = (ss_handle_t *) (buf - SS_HANDLE_OFFSET);
	  if (ss_handle->majik != SS_BUF_MAJIK)
	      call Panic.panic(PANIC_SS, 14, ss_handle->majik, 0, 0, 0);
	  if (ss_handle->buf_state != SS_BUF_STATE_ALLOC)
	      call Panic.panic(PANIC_SS, 15, ss_handle->buf_state, 0, 0, 0);

	  if (&ss_handles[ssc.in_index] != ss_handle)
	      call Panic.panic(PANIC_SS, 16, (uint16_t) ss_handle, 0, 0, 0);

#ifdef notdef
	  /*
	   * this is no longer true.  If another entity is using the us1
	   * hardware the MS component can be held off and it won't come
	   * out of OFF or IDLE.
	   */

	  /*
	   * Since we were off or idle, the next one to go out had
	   * better be the one that just came in.
	   */
	  if (ssc.in_index != ssc.out_index)
	      call Panic.panic(PANIC_SS, 17, (uint16_t) ss_handle, 0, 0, 0);
#endif

	  ss_handle->buf_state = SS_BUF_STATE_FULL;
	  ssc.num_full++;
	  if (ssc.num_full > ssc.max_full)
	      ssc.max_full = ssc.num_full;
	  ssc.in_index++;
	  if (ssc.in_index >= SS_NUM_BUFS)
	      ssc.in_index = 0;

	  /*
	   * We are ready to hit the h/w.  1st check to see if the h/w
	   * is busy.  If so then bail early.  However if we've been
	   * busy too long, then take it anyway and inform the other
	   * subsystems.
	   *
	   * Because of multiplexing we may have buffers that are backed
	   * up.  The buffer that just came in may not be the one that
	   * needs to go out next.  Once we get the hardware, make sure
	   * to send out the next one that should go.  ssc.out_index
	   * is the one that should go.
	   */
	  if (us1_busy(US1_SD)) {
	      /*
	       * someone else has the hardware.  See how many
	       * buffers we have queued up.  If we have SS_CRITICAL_BUFS
	       * (or more) buffs waiting then force ownership of the hardware.
	       *
	       * If we force the hardware we also need to tell the other
	       * subsystems (GPS and COMM) that something happened so they
	       * can recover.
	       */
	      if (ssc.num_full < SS_CRITICAL_BUFS)
		  return;

	      if (us1_select(US1_NONE, FALSE))
		  call Panic.panic(PANIC_SS, 36, 0, 0, 0, 0);

	      /*
	       * tell other subsystems that they had the h/w yanked away.
	       */
	  }

	  if (ssc.ss_state == SS_STATE_OFF) {
	      /*
	       * turn the power on and point the h/w at the SD card.
	       *
	       * we currently force the select.  we shouldn't need to
	       * do this but only need to because things are currently
	       * kludged to force return to a particular serial device.
	       */
	      us1_sd_pwr_on();
//	      if (us1_select(US1_SD, FALSE))
	      if (us1_select(US1_SD, TRUE))
		  call Panic.panic(PANIC_SS, 39, 0, 0, 0, 0);

	      /*
	       * do we need to try multiple times?
	       */
	      err = sd_reset();
	      if (err)
		  call Panic.panic(PANIC_SS, 18, err, 0, 0, 0);
	  } else {
//	      if (us1_select(US1_SD, FALSE))
	      if (us1_select(US1_SD, TRUE))
		  call Panic.panic(PANIC_SS, 37, 0, 0, 0, 0);
	  }


	  /*
	   * we may be backed up.  Use the next one that should
	   * go out.
	   */
	  ss_handle = &ss_handles[ssc.out_index];
	  if (ss_handle->buf_state != SS_BUF_STATE_FULL)
	      call Panic.panic(PANIC_SS, 40, ss_handle->buf_state, 0, 0, 0);

	  time_get_cur(&t);
	  add_times(&t, &ss_write_timeout_delay);
	  mtd.which = SS_TIME_WRITE_TIMEOUT;
	  if (ss_wto_handle != TIMER_HANDLE_FREE)
	      call Panic.panic(PANIC_SS, 33, ss_wto_handle, 0, 0, 0);
	  ss_wto_handle = timer_set(&t, ss_write_timeout, &mtd);
	  ss_handle->buf_state = SS_BUF_STATE_WRITING;
	  err =
	      sd_start_write(NULL, ssc.dblk_nxt, ss_handle->buf);
	  if (err)
	      call Panic.panic(PANIC_SS, 19, err, 0, 0, 0);
	  ssc.ss_state = SS_STATE_XFER;
	  DMA0CTL_bit.DMAIE = 1;
	  return;
	      
      case SS_STATE_XFER:
	  /*
	   * We are in the process of sending a buffer out.
	   *
	   * Msg Buffer_Full says we completed another buffer
	   * do nothing it will get picked up when the current
	   * one finishes.
	   *
	   * msg_ss_DMA_Complete, DMA interrupt signalled
	   * completion.  Check the transfer.  Then fire up
	   * the next buffer.
	   *
	   * msg_ss_Timer_Expiry, Oops.  transfer time out.
	   */
	  if (msg->msg_id == msg_ss_Buffer_Full) {
	      /*
	       * Back up to get the handle from the buffer ptr.
	       * And do some sanity checks.  (Majik should match,
	       * buffer state needs to be allocated, and the buffer
	       * being passed in needed to be the next one expected
	       * (in_index)).
	       */
	      ss_handle = (ss_handle_t *) (buf - SS_HANDLE_OFFSET);
	      if (ss_handle->majik != SS_BUF_MAJIK)
		  call Panic.panic(PANIC_SS, 20, ss_handle->majik, 0, 0, 0);
	      if (ss_handle->buf_state != SS_BUF_STATE_ALLOC)
		  call Panic.panic(PANIC_SS, 21, ss_handle->buf_state, 0, 0, 0);
	      if (&ss_handles[ssc.in_index] != ss_handle)
		  call Panic.panic(PANIC_SS, 22, (uint16_t) ss_handle, 0, 0, 0);

	      /*
	       * Switch to Full, bump the next expected and
	       * that's all she wrote.
	       */
	      ss_handle->buf_state = SS_BUF_STATE_FULL;
	      ssc.num_full++;
	      if (ssc.num_full > ssc.max_full)
		  ssc.max_full = ssc.num_full;
	      ssc.in_index++;
	      if (ssc.in_index >= SS_NUM_BUFS)
		  ssc.in_index = 0;
	      return;
	  }

	  if (msg->msg_id == msg_ss_DMA_Complete) {
	      /*
	       * DMA completed.  Still need to wait for
	       * the write to complete.  Err return can
	       * be SD_OK (0), SD_RETRY (try again), or
	       * something else.
	       *
	       * For now everything dies if something goes wrong.
	       */
	      err =
		  sd_finish_write();
	      if (err)
		  call Panic.panic(PANIC_SS, 23, err, 0, 0, 0);

	      /*
	       * Write has finished A-OK.  Free the buffer and
	       * advance to the next buffer.  If that one is FULL
	       * start up the next write.
	       *
	       * If nothing else to do, power down and return to
	       * OFF state.
	       */
	      if (ss_handles[ssc.out_index].buf_state != SS_BUF_STATE_WRITING)
		  call Panic.panic(PANIC_SS, 32, ss_handles[ssc.out_index].buf_state, 0, 0, 0);
	      ss_handles[ssc.out_index].buf_state = SS_BUF_STATE_FREE;
	      ssc.num_full--;
	      ssc.out_index++;
	      if (ssc.out_index >= SS_NUM_BUFS)
		  ssc.out_index = 0;
	      ssc.dblk_nxt++;
	      if (ssc.dblk_nxt >= ssc.dblk_end)
		  call Panic.panic(PANIC_SS, 35, err, 0, 0, 0);

	      /*
	       * See if the next buffer needs to be written.
	       */
	      if (ss_handles[ssc.out_index].buf_state == SS_BUF_STATE_FULL) {
		  time_get_cur(&t);
		  add_times(&t, &ss_write_timeout_delay);
		  mtd.which = SS_TIME_WRITE_TIMEOUT;
		  if (ss_wto_handle != TIMER_HANDLE_FREE)
		      call Panic.panic(PANIC_SS, 34, ss_wto_handle, 0, 0, 0);
		  ss_wto_handle = timer_set(&t, ss_write_timeout, &mtd);
		  ss_handles[ssc.out_index].buf_state = SS_BUF_STATE_WRITING;
		  err =
		      sd_start_write(NULL, ssc.dblk_nxt, ss_handles[ssc.out_index].buf);
		  if (err)
		      call Panic.panic(PANIC_SS, 19, err, 0, 0, 0);
		  DMA0CTL_bit.DMAIE = 1;
		  return;
	      }

	      /*
	       * Not Full.  For now just go idle.  and dump the h/w so
	       * a different subsystem can get it.
	       */
	      ssc.ss_state = SS_STATE_IDLE;
	      if (us1_select(US1_NONE, FALSE))
		  call Panic.panic(PANIC_SS, 38, 0, 0, 0, 0);
	      return;
	      
	  } else if (msg->msg_id == msg_ss_Timer_Expiry) {
	      /*
	       * shouldn't ever time out.  For now just panic.
	       */
	      call Panic.panic(PANIC_SS, 24, msg->msg_id, 0, 0, 0);

	  } else {
	      /*
	       * something odd is going on
	       */
	      call Panic.panic(PANIC_SS, 25, msg->msg_id, 0, 0, 0);
	  }
	  break;

      default:
	  call Panic.panic(PANIC_SS, 27, msg->msg_id, 0, 0, 0);
    }
}


#pragma vector=DACDMA_VECTOR
__interrupt void SS_DMA_Complete_Int(void) {

    TRACE_INT("I_ss_dma");

    /*
     * Had better be DMA0 yanking our chain.
     *
     * Kick the interrupt flag to off and disable DMA0 interrupts.
     * They will get turned back on with the next buffer
     * that goes out via ss_machine.
     */
    if (DMA0CTL_bit.DMAIFG == 0)
	call Panic.panic(PANIC_SS, 28, 0, 0, 0, 0);
    if (us1_sel != US1_SD)
	call Panic.panic(PANIC_SS, 29, 0, 0, 0, 0);
    DMA0CTL_bit.DMAIFG = 0;
    DMA0CTL_bit.DMAIE = 0;
    if (ssc.out_index >= SS_NUM_BUFS ||
	  (ss_handles[ssc.out_index].buf_state != SS_BUF_STATE_WRITING) ||
	  (ss_wto_handle >= N_TIMERS))
	call Panic.panic(PANIC_SS, 30, 0, 0, 0, 0);
    mm_timer_delete(ss_wto_handle, ss_write_timeout);
    ss_wto_handle = TIMER_HANDLE_FREE;
    sched_enqueue(TASK_MS, msg_ss_DMA_Complete, MSG_ADDR_MS, (msg_param_t) (&ss_handles[ssc.out_index]));
    __low_power_mode_off_on_exit();
}
