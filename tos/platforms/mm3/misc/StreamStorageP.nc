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
 * StreamStorage provides a write interface that will write sequenctial
 * blocks of the storage device.  One 512 byte block at a time. There
 * are no provisions for a file system or for access currently.
 *
 * StreamStorage provides a pool of buffers to its users and manages
 * when those buffers get written to the SD.
 *
 * Copyright 2008 (c) Eric B. Decker
 * Mam-Mark Project
 * All rights reserved.
 *
 * Based on ms_sd.c - Stream Storage Interface - SD direct interface
 * Copyright 2006-2007, Eric B. Decker
 * Mam-Mark Project
 *
 * Overview:
 *
 * This is a threaded tinyos 2 implementation.  The main thread is responsible
 * for managing SD state, turning it on, seeing buffers that need work etc.
 *
 * When it has work, it turns on the SD (which takes some time), performs the
 * work.  When there is no more work, it will power down the SD.
 *
 * Currently, the only work it has is to write buffers to the SD.  On boot up
 * it will turn the SD on and search the data area (obtained from the data block
 * locator in the MBR) for the first zero block which is assumed to be the first
 * erased block.  New blocks handed to it will be written starting at the sector.
 */

#include "stream_storage.h"
#include "dblk_loc.h"

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

uint32_t w_t0, w_diff;

#ifdef ENABLE_ERASE
#ifdef ALWAYS_ERASE
bool     do_erase = 1;
#else
bool     do_erase;
#endif
uint32_t erase_start;
uint32_t erase_end;
#endif

module StreamStorageP {
  provides {
    interface Init;
    interface StreamStorage as SS;
    interface StreamStorageFull as SSF;
    interface Boot as BlockingBoot;
    interface ResourceConfigure;
  }
  uses {
    interface Boot;
    interface Thread as SSWriter;
    interface Thread as SSReader;
    interface SD;
    interface HplMM3Adc as HW;
    interface Semaphore;
    interface BlockingResource as BlockingWriteResource;
    interface BlockingResource as BlockingReadResource;
    interface ResourceConfigure as SpiResourceConfigure;
    interface Panic;
    interface LocalTime<TMilli>;
    interface Trace;
  }
}
  
implementation {
  ssw_buf_handle_t ssw_handles[SSW_NUM_BUFS];
  ssw_buf_handle_t * const ssh_ptrs[SSW_NUM_BUFS] = {
    &ssw_handles[0],
    &ssw_handles[1],
    &ssw_handles[2],
    &ssw_handles[3]
  };

#if SSW_NUM_BUFS != 4
#warning "SSW_NUM_BUFS is other than 4"
#endif

  /*
   * Stream Storage control state
   * (see stream_storage.h for documentation)
   *
   * ss_state pulled out to deal with asyncronous state setting.
   */

  ssw_state_t ssw_state;	// current state of machine (2 bytes)
  ss_control_t ssc;

  semaphore_t write_sem;


  /*
   * Globals for the Stream Read interface
   */

  semaphore_t read_sem;
  uint32_t m_rblock;
  uint8_t *m_rbuf;
  ssr_state_t ssr_state;
  ssr_req_t ssr_reqs[SSR_NUM_REQS];


  command error_t Init.init() {
    uint16_t i;

    call Semaphore.reset(&write_sem, 0);
    call Semaphore.reset(&read_sem, 0);
    ssw_state        = SSW_STATE_OFF;
    ssr_state	     = SSR_STATE_OFF;

    ssc.majik_a     = SSC_MAJIK_A;
    ssc.alloc_index = 0;
    ssc.in_index    = 0;
    ssc.out_index   = 0;
    ssc.num_full    = 0;
    ssc.max_full    = 0;

    ssc.panic_start = ssc.panic_end = 0;
    ssc.config_start= ssc.config_end = 0;
    ssc.dblk_start  = ssc.dblk_end = 0;
    ssc.dblk_nxt    = 0;
    ssc.majik_b     = SSC_MAJIK_B;

    for (i = 0; i < SSW_NUM_BUFS; i++) {
      ssw_handles[i].majik     = SSW_BUF_MAJIK;
      ssw_handles[i].buf_state = SSW_BUF_STATE_FREE;
      ssw_handles[i].stamp = 0;
    }
    return SUCCESS;
  }


  event void Boot.booted() {
    call SSWriter.start(NULL);
    call SSReader.start(NULL);
  }
  

  void ss_panic(uint8_t where, uint16_t err) {
    call Panic.panic(PANIC_SS, where, err, 0, 0, 0);
  }


  /* StreamStorage.buffer_full()
   *
   * called from the client to indicate that it has
   * filled the buffer.
   *
   * This is callable from anywhere and will wake the SS
   * thread up to get something done on the SD.
   *
   * Note that the buffers get allocated and handed back
   * in strict order so all we have to do is hit the
   * semaphore.  But to be paranoid we use the queue and
   * check it.
   *
   * Actually we could do the checks here and then kick
   * the semaphore.  The thread just runs down the
   * buffers in order.
   */

  command void SS.buffer_full(ssw_buf_handle_t *handle) {
    ssw_buf_handle_t *sshp;
    uint8_t in_index;

    /*
     * handles should be flushed in strict order.  So the next one
     * in should be where in_index points.
     */
    in_index = ssc.in_index;
    sshp = ssh_ptrs[in_index];
    if (&ssw_handles[in_index] != sshp) // shouldn't ever happen,  uses math
      ss_panic(10, (uint16_t) sshp);

    /* the next check also catches the null pointer */
    if (sshp != handle ||
	handle->majik != SSW_BUF_MAJIK ||
	handle->buf_state != SSW_BUF_STATE_ALLOC) {
      call Panic.panic(PANIC_SS, 11, (uint16_t) handle, handle->majik, handle->buf_state, (uint16_t) sshp);
    }

    if (ssc.majik_a != SSC_MAJIK_A || ssc.majik_b != SSC_MAJIK_B)
      call Panic.panic(PANIC_SS, 12, ssc.majik_a, ssc.majik_b, 0, 0);

    /*
     * Strictly speaking this doesn't need to be atomic.  But buf_state
     * is what controls the SSWriter handling outgoing write buffers.
     */
    handle->stamp = call LocalTime.get();
    atomic {
      handle->buf_state = SSW_BUF_STATE_FULL;
      ssc.num_full++;
      if (ssc.num_full > ssc.max_full)
	ssc.max_full = ssc.num_full;
    }
    ssc.in_index++;
    if (ssc.in_index >= SSW_NUM_BUFS)
      ssc.in_index = 0;
    call Semaphore.release(&write_sem);
  }


  /*
   * blk_empty
   *
   * check if a Stream storage data block is empty.
   * Currently, an empty (erased SD data block) looks like
   * it is zeroed.  So we look for all data being zero.
   */

  int blk_empty(uint8_t *buf) {
    uint16_t i;
    uint16_t *ptr;

    ptr = (void *) buf;
    for (i = 0; i < SD_BLOCKSIZE/2; i++)
      if (ptr[i])
	return(0);
    return(1);
  }


  command bool SS.buffer_empty(uint8_t *buf) {
    return blk_empty(buf) == 1;
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

  uint16_t check_dblk_loc(dblk_loc_t *dbl) {
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


  error_t read_blk_fail(uint32_t blk, uint8_t *buf) {
    error_t err;

    err = call SD.read(blk, buf);
    if (err) {
      ss_panic(13, err);
      return err;
    }
    return err;
  }


  error_t ss_boot() {
    error_t err;
    uint8_t *dp;
    dblk_loc_t *dbl;
    uint32_t   lower, blk, upper;
    bool empty;

    err = call SD.reset();
    if (err) {
      ss_panic(14, err);
      return err;
    }

    dp = ssw_handles[0].buf;
    if ((err = read_blk_fail(0, dp)))
      return err;

    dbl = (void *) ((uint8_t *) dp + DBLK_LOC_OFFSET);

#ifdef notdef
    if (do_test)
      sd_display_card(dp);
#endif

    if (check_dblk_loc(dbl)) {
      ss_panic(15, -1);
      return FAIL;
    }

    ssc.panic_start  = CF_LE_32(dbl->panic_start);
    ssc.panic_end    = CF_LE_32(dbl->panic_end);
    ssc.config_start = CF_LE_32(dbl->config_start);
    ssc.config_end   = CF_LE_32(dbl->config_end);
    ssc.dblk_start   = CF_LE_32(dbl->dblk_start);
    ssc.dblk_end     = CF_LE_32(dbl->dblk_end);

#ifdef ENABLE_ERASE
    if (do_erase) {
      erase_start = ssc.dblk_start;
      erase_end   = ssc.dblk_end;
      nop();
      call SD.erase(erase_start, erase_end);
    }
#endif
    if ((err = read_blk_fail(ssc.dblk_start, dp))) {
      ss_panic(16, -1);
      return err;
    }

    if (blk_empty(dp)) {
      ssc.dblk_nxt = ssc.dblk_start;
      return SUCCESS;
    }

    lower = ssc.dblk_start;
    upper = ssc.dblk_end;
    empty = 0; blk = 0;

    while (lower < upper) {
      blk = (upper - lower)/2 + lower;
      if (blk == lower)
	blk = lower = upper;
      if ((err = read_blk_fail(blk, dp)))
	return err;
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

    /* for now force to always hit the start. */
//    empty = 1; blk = ssc.dblk_start;

    if (empty) {
      ssc.dblk_nxt = blk;
      return SUCCESS;
    }

    ss_panic(17, -1);
    return FAIL;
  }


  command ssw_buf_handle_t* SS.get_free_buf_handle() {
    ssw_buf_handle_t *sshp;

    sshp = ssh_ptrs[ssc.alloc_index];
    if (ssc.alloc_index >= SSW_NUM_BUFS ||
	ssc.majik_a != SSC_MAJIK_A ||
	ssc.majik_b != SSC_MAJIK_B ||
	sshp->buf_state < SSW_BUF_STATE_FREE ||
	sshp->buf_state >= SSW_BUF_STATE_MAX) {
      ss_panic(18, -1);
      return NULL;
    }

    if (sshp->buf_state == SSW_BUF_STATE_FREE) {
      if (sshp->majik != SSW_BUF_MAJIK) {
	ss_panic(19, -1);
	return NULL;
      }
      sshp->stamp = call LocalTime.get();
      sshp->buf_state = SSW_BUF_STATE_ALLOC;
      ssc.alloc_index++;
      if (ssc.alloc_index >= SSW_NUM_BUFS)
	ssc.alloc_index = 0;
      return sshp;
    }
    ss_panic(20, -1);
    return NULL;
  }


  command uint8_t *SS.buf_handle_to_buf(ssw_buf_handle_t *handle) {
    if (!handle || handle->majik != SSW_BUF_MAJIK ||
	handle->buf_state != SSW_BUF_STATE_ALLOC) {
      ss_panic(21, -1);
      return NULL;
    }
    return handle->buf;
  }


  async command void ResourceConfigure.configure() {
    ssw_state_t cur_state;

    atomic cur_state = ssw_state;
    switch(cur_state) {
      default:
      case SSW_STATE_CRASHED:
      case SSW_STATE_XFER:
	ss_panic(22, cur_state);
	break;

      case SSW_STATE_OFF:
	  call HW.sd_on();
	  atomic ssw_state = SSW_STATE_IDLE;
      case SSW_STATE_IDLE:
	call SpiResourceConfigure.configure();
    }
  }


  async command void ResourceConfigure.unconfigure() {
    switch(ssw_state) {
      default:
      case SSW_STATE_CRASHED:
      case SSW_STATE_OFF:
	ss_panic(23, ssw_state);
	break;

	/* If IDLE turn the device off and then deconfigure.
	 * If doing a transfer then leave power on so the
	 * transfer can complete.  Upon conclusion we will
	 * have to reacquire the bus to finish.
	 */
      case SSW_STATE_IDLE:
	call HW.sd_off();	// and then unconfigure
	ssw_state = SSW_STATE_OFF;
      case SSW_STATE_XFER:
	call SpiResourceConfigure.unconfigure();
	break;
    }
  }


  event void SSWriter.run(void* arg) {
    ssw_buf_handle_t* cur_handle;
    error_t err;
    ssw_state_t cur_state;

    /*
     * call the system to arbritrate and configure the SPI
     * we use the default configuration for now which matches
     * what we need.
     */
    
    call BlockingWriteResource.request();

    /*
     * First start up and read in control blocks.
     * Then signal we have booted.
     */
    if ((err = ss_boot())) {
      ss_panic(24, err);
    }

    /*
     * releasing when IDLE will power the device down.
     * and set our current state to OFF.
     */
    atomic ssw_state = SSW_STATE_IDLE;
    call BlockingWriteResource.release();
    signal BlockingBoot.booted();

    for(;;) {
      call Semaphore.acquire(&write_sem);

      /*
       * if the next out buffer indicates it isn't full then we are seeing
       * the ghost artifact from a race condition between thread and task level
       * The thread loop may have already processed the buffer and now we need
       * to clean up the semaphore.
       *
       * The access of buf_state is atomic so shouldn't have a race problem with
       * the task level.
       */
      cur_handle = ssh_ptrs[ssc.out_index];
      if (cur_handle->buf_state != SSW_BUF_STATE_FULL)
	continue;

      /*
       * When running a simple sensor regime (all 1 sec, mag/accel 51mis) and writing out
       * all packets to the serial port, gathering 3 causes a panic.  There isn't enough
       * time for Stream Storage to gain  control.
       */

      if (ssc.num_full < 3)	// for now gather three up and ship out together
	continue;

      /*
       * Only power up and obtain the SPI bus if the stream isn't full
       */

      if (ssc.dblk_nxt != 0) {
	/*
	 * should be OFF or if implemented in OFF_WAIT (which implements
	 * a delay prior to shutting the hardware off.  But if we are in OFF_WAIT
	 * we won't be here but rather later down in this processing loop.
	 */
	atomic cur_state = ssw_state;
	if (cur_state != SSW_STATE_OFF) {
	  call Panic.warn(PANIC_SS_RECOV, 25, cur_state, 0, 0, 0);
	  atomic cur_state = ssw_state = SSW_STATE_OFF;
	}

	call BlockingWriteResource.request(); // this will also turn on the hardware when granted.
	err = call SD.reset();		  // about 100ms
	if (err) {
	  ss_panic(26, err);
	  continue;
	}
	atomic ssw_state = SSW_STATE_IDLE;
      }

      for (;;) {
	/*
	 * current buffer needs to be full if we have work to do
	 */
	if (cur_handle->buf_state != SSW_BUF_STATE_FULL)
	  break;

	if (ssc.dblk_nxt != 0) {
	  /*
	   * If dblk_nxt is 0 then the dblk stream is full and we
	   * shouldn't do anymore writes.
	   *
	   * the write needs a time out of some kind.
	   * The write runs to completion.
	   *
	   * Observed 5ms write time unerased block.
	   */
	  cur_handle->stamp = call LocalTime.get();
	  cur_handle->buf_state = SSW_BUF_STATE_WRITING;
	  atomic ssw_state = SSW_STATE_XFER;
	  w_t0 = call LocalTime.get();
	  err = call SD.write(ssc.dblk_nxt, cur_handle->buf);
	  if (err)
	    ss_panic(27, err);
	  w_diff = call LocalTime.get() - w_t0;
	}

	cur_handle->stamp = call LocalTime.get();
	cur_handle->buf_state = SSW_BUF_STATE_FREE;
	ssc.out_index++;
	if (ssc.out_index >= SSW_NUM_BUFS)
	  ssc.out_index = 0;
	ssc.num_full--;
	if (ssc.dblk_nxt != 0) {
	  if (ssc.dblk_nxt >= ssc.dblk_end) {
	    /*
	     * We also might want to check for next to last and
	     * write a record indicating this via Collect.
	     *
	     * NOTE: the SSF.dblk_stream_full signal executes on
	     * the thread stack.  Just be aware.
	     */
	    signal SSF.dblk_stream_full();
	    ssc.dblk_nxt = 0;
	    atomic ssw_state = SSW_STATE_IDLE;
	    call BlockingWriteResource.release(); // will shutdown the hardware
	  } else
	    ssc.dblk_nxt++;
	}
	cur_handle = ssh_ptrs[ssc.out_index];
      }

      if (ssc.dblk_nxt != 0) {
	/*
	 * Only have to release if the stream is active
	 *
	 * This is where to implement OFF_WAIT
	 * For now we just go idle and release
	 */
	atomic ssw_state = SSW_STATE_IDLE;
	call BlockingWriteResource.release(); // will shutdown the hardware
      }
    }
  }


  /*****************************************************************************
   *
   * READING
   *
   */

  command error_t SS.read_block(uint32_t blk, uint8_t *buf) {
    return SUCCESS;
  }

  command uint32_t SS.area_start(uint8_t which) {
    return 0;
  }

  command uint32_t SS.area_end(uint8_t which) {
    return 0;
  }

  event void SSReader.run(void* arg) {
    for(;;) {
      call Semaphore.acquire(&read_sem);

      call BlockingReadResource.request();
      call SSReader.sleep(1024);
      call BlockingReadResource.release();
      call SSReader.sleep(1024);

    }
  }

#ifdef notdef
  void ss_machine(msg_event_t *msg) {
    uint8_t     *buf;
    ssw_buf_handle_t	*ss_handle;
    ss_timer_data_t mtd;
    mm_time_t       t;
    sd_rtn	 err;

    switch(ssw_state) {
      case SSW_STATE_OFF:
      case SSW_STATE_IDLE:
	/*
	 * Only expected message is Buffer_Full.  Others
	 * are weird.
	 */
	if (msg->msg_id != msg_ss_Buffer_Full)
	  panic();

	/*
	 * back up to get the full handle.  The buffer
	 * coming back via the buffer_full msg had better
	 * be allocated as well as the next one we expect.
	 * Next one expected is ssc.in_index.
	 */
	ss_handle = (ssw_buf_handle_t *) (buf - SS_HANDLE_OFFSET);
	if (ss_handle->majik != SSW_BUF_MAJIK)
	  panic();
	if (ss_handle->buf_state != SSW_BUF_STATE_ALLOC)
	  panic();

	if (&ssw_handles[ssc.in_index] != ss_handle)
	  panic();

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
	  panic();
#endif

	ss_handle->buf_state = SSW_BUF_STATE_FULL;
	ssc.num_full++;
	if (ssc.num_full > ssc.max_full)
	  ssc.max_full = ssc.num_full;
	ssc.in_index++;
	if (ssc.in_index >= SSW_NUM_BUFS)
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
	    panic();

	  /*
	   * tell other subsystems that they had the h/w yanked away.
	   */
	}

	if (ssw_state == SSW_STATE_OFF) {
	  /*
	   * turn the power on and point the h/w at the SD card.
	   *
	   * we currently force the select.  we shouldn't need to
	   * do this but only need to because things are currently
	   * kludged to force return to a particular serial device.
	   */
	  us1_sd_pwr_on();
	  if (us1_select(US1_SD, TRUE))
	    panic();

	  /*
	   * do we need to try multiple times?
	   */
	  err = sd_reset();
	  if (err)
	    panic();
	} else {
	  if (us1_select(US1_SD, TRUE))
	    panic();
	}


	/*
	 * we may be backed up.  Use the next one that should
	 * go out.
	 */
	ss_handle = &ssw_handles[ssc.out_index];
	if (ss_handle->buf_state != SSW_BUF_STATE_FULL)
	  panic();

	time_get_cur(&t);
	add_times(&t, &ss_write_timeout_delay);
	mtd.which = SS_TIME_WRITE_TIMEOUT;
	if (ss_wto_handle != TIMER_HANDLE_FREE)
	  panic();
	ss_wto_handle = timer_set(&t, ss_write_timeout, &mtd);
	ss_handle->buf_state = SSW_BUF_STATE_WRITING;
	err =
	  sd_start_write(NULL, ssc.dblk_nxt, ss_handle->buf);
	if (err)
	  panic();
	ssw_state = SSW_STATE_XFER;
	DMA0CTL_bit.DMAIE = 1;
	return;
	      
      case SSW_STATE_XFER:
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
	  ss_handle = (ssw_buf_handle_t *) (buf - SS_HANDLE_OFFSET);
	  if (ss_handle->majik != SSW_BUF_MAJIK)
	    panic();
	  if (ss_handle->buf_state != SSW_BUF_STATE_ALLOC)
	    panic();
	  if (&ssw_handles[ssc.in_index] != ss_handle)
	    panic();

	  /*
	   * Switch to Full, bump the next expected and
	   * that's all she wrote.
	   */
	  ss_handle->buf_state = SSW_BUF_STATE_FULL;
	  ssc.num_full++;
	  if (ssc.num_full > ssc.max_full)
	    ssc.max_full = ssc.num_full;
	  ssc.in_index++;
	  if (ssc.in_index >= SSW_NUM_BUFS)
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
	    panic();

	  /*
	   * Write has finished A-OK.  Free the buffer and
	   * advance to the next buffer.  If that one is FULL
	   * start up the next write.
	   *
	   * If nothing else to do, power down and return to
	   * OFF state.
	   */
	  if (ssw_handles[ssc.out_index].buf_state != SSW_BUF_STATE_WRITING)
	    panic();
	  ssw_handles[ssc.out_index].buf_state = SSW_BUF_STATE_FREE;
	  ssc.num_full--;
	  ssc.out_index++;
	  if (ssc.out_index >= SSW_NUM_BUFS)
	    ssc.out_index = 0;
	  ssc.dblk_nxt++;
	  if (ssc.dblk_nxt >= ssc.dblk_end)
	    panic();

	  /*
	   * See if the next buffer needs to be written.
	   */
	  if (ssw_handles[ssc.out_index].buf_state == SSW_BUF_STATE_FULL) {
	    time_get_cur(&t);
	    add_times(&t, &ss_write_timeout_delay);
	    mtd.which = SS_TIME_WRITE_TIMEOUT;
	    if (ss_wto_handle != TIMER_HANDLE_FREE)
	      panic();
	    ss_wto_handle = timer_set(&t, ss_write_timeout, &mtd);
	    ssw_handles[ssc.out_index].buf_state = SSW_BUF_STATE_WRITING;
	    err =
	      sd_start_write(NULL, ssc.dblk_nxt, ssw_handles[ssc.out_index].buf);
	    if (err)
	      panic();
	    DMA0CTL_bit.DMAIE = 1;
	    return;
	  }

	  /*
	   * Not Full.  For now just go idle.  and dump the h/w so
	   * a different subsystem can get it.
	   */
	  ssw_state = SSW_STATE_IDLE;
	  if (us1_select(US1_NONE, FALSE))
	    panic();
	  return;
	      
	} else if (msg->msg_id == msg_ss_Timer_Expiry) {
	  /*
	   * shouldn't ever time out.  For now just panic.
	   */
	  panic();
	} else {
	  /*
	   * something odd is going on
	   */
	  panic();
	}
	break;

      default:
	panic();
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
      panic();
    if (us1_sel != US1_SD)
      panic();
    DMA0CTL_bit.DMAIFG = 0;
    DMA0CTL_bit.DMAIE = 0;
    if (ssc.out_index >= SSW_NUM_BUFS ||
	(ssw_handles[ssc.out_index].buf_state != SSW_BUF_STATE_WRITING) ||
	(ss_wto_handle >= N_TIMERS))
      panic();
    mm_timer_delete(ss_wto_handle, ss_write_timeout);
    ss_wto_handle = TIMER_HANDLE_FREE;
    sched_enqueue(TASK_MS, msg_ss_DMA_Complete, MSG_ADDR_MS, (msg_param_t) (&ssw_handles[ssc.out_index]));
    __low_power_mode_off_on_exit();
  }

#endif

}
