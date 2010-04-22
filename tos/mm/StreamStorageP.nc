/*
 * Copyright (c) 2008, 2010 - Eric B. Decker
 * All rights reserved.
 *
 * StreamStorage.nc - write/read sequential blocks to/from
 * a contiguous data area.  The area is considered a file
 * and managed by the file system such as it is.
 *
 * The principal interface provided by StreamStorage is writing sequential
 * blocks to the the storage device.  Other than that there is no file
 * semantics.
 *
 * SSW (StreamStorageWriter) provides a pool of buffers to its users and manages
 * when those buffers get written to the SD.
 *
 * The calling user of Reader provides the buffer.
 *
 * Overview:
 *
 * This is a threaded tinyos 2 implementation.  Two threads exist, one for
 * writing and one for reading.  To avoid conflict they independently
 * arbritrate for the resources needed.
 *
 * When it has work, it turns on the SD (which takes some time), performs the
 * work.  When there is no more work, it will power down the SD.  To amortize
 * the power on overhead, the reader/writer threads may combine accesses.  That
 * is wait until it has groups of buffers to work on.
 *
 * The Writer thread is responsible for boot up.  On boot, it will turn the SD
 * on and perform any initilization needed (set up the main control structure
 * using data on the SD itself).
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
    interface StreamStorageWrite as SSW;
    interface StreamStorageRead  as SSR[uint8_t client_id];
    interface StreamStorageFull  as SSF;
//    interface Boot as OutBoot;
//    interface ResourceConfigure;
  }
  uses {
//    interface Boot;
    interface SDreset;
    interface SDread;
    interface SDwrite;
    interface SDerase;
    interface Hpl_MM_hw as HW;
    interface Resource as WriteResource;
    interface Resource as ReadResource;
//    interface ResourceConfigure as SpiResourceConfigure;
    interface Panic;
    interface LocalTime<TMilli>;
    interface Trace;
    interface LogEvent;
  }
}
  
implementation {

  typedef struct {
    uint8_t  cid;			/* client id */
    uint32_t blk;
    uint8_t *buf;
    error_t  err;
  } read_block_t;
  

  ss_wr_req_t ssw_handles[SSW_NUM_BUFS];
  ss_wr_req_t * const ssw_p[SSW_NUM_BUFS] = {
    &ssw_handles[0],
    &ssw_handles[1],
    &ssw_handles[2],
    &ssw_handles[3]
  };

#if SSW_NUM_BUFS != 4
#warning "SSW_NUM_BUFS is other than 4"
#endif

#if SSR_NUM_REQS != 4
#warning "SSR_NUM_REQS is other than 4"
#endif

  /*
   * Stream Storage control state
   * (see stream_storage.h for documentation)
   *
   * ss_state pulled out to deal with asyncronous state setting.
   */

  ss_state_t ss_state;		 // current state of machine (2 bytes)
  ss_control_t ssc;


  /*
   * Globals for the Stream Read interface
   */

  ss_rd_req_t ssr_reqs[SSR_NUM_REQS];
  ss_rd_req_t * const ssr_p[SSR_NUM_REQS] = {
    &ssr_reqs[0],
    &ssr_reqs[1],
    &ssr_reqs[2],
    &ssr_reqs[3]
  };

  /*
   * instrumentation for measuring how long things take.
   */
  uint32_t ssw_delay_start;		// how long are we held off?
  uint32_t ssw_write_grp_start;		// when we start the write of the group.

  command error_t Init.init() {
    uint16_t i;

    ss_state        = SS_STATE_OFF;

    ssc.majik_a     = SSC_MAJIK_A;
    ssc.ssw_alloc   = 0;
    ssc.ssw_in      = 0;
    ssc.ssw_out     = 0;
    ssc.ssw_num_full= 0;
    ssc.ssw_max_full= 0;

    ssc.ssr_in      = 0;
    ssc.ssr_out     = 0;
    ssc.majik_b     = SSC_MAJIK_B;

    for (i = 0; i < SSW_NUM_BUFS; i++) {
      ssw_p[i]->majik     = SS_REQ_MAJIK;
      ssw_p[i]->req_state = SS_REQ_STATE_FREE;
      ssw_p[i]->stamp     = 0;
    }

    for (i = 0; i < SSR_NUM_REQS; i++) {
      ssr_p[i]->majik     = SS_REQ_MAJIK;
      ssr_p[i]->req_state = SS_REQ_STATE_FREE;
      ssr_p[i]->stamp     = 0;
    }
    return SUCCESS;
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

  command void SSW.buffer_full(ss_wr_req_t *handle) {
    ss_wr_req_t *sswp;
    uint8_t in_index;

    /*
     * handles should be flushed in strict order.  So the next one
     * in should be where in_index points.
     */
    in_index = ssc.ssw_in;
    sswp = ssw_p[in_index];
    if (in_index >= SSW_NUM_BUFS)
      ss_panic(10, in_index);

    /* the next check also catches the null pointer */
    if (sswp != handle ||
	handle->majik != SS_REQ_MAJIK ||
	handle->req_state != SS_REQ_STATE_ALLOC) {
      call Panic.panic(PANIC_SS, 11, (uint16_t) handle, handle->majik, handle->req_state, (uint16_t) sswp);
    }

    if (ssc.majik_a != SSC_MAJIK_A || ssc.majik_b != SSC_MAJIK_B)
      call Panic.panic(PANIC_SS, 12, ssc.majik_a, ssc.majik_b, 0, 0);

    /*
     * Strictly speaking this doesn't need to be atomic.  But req_state
     * is what controls the SSWriter handling outgoing write buffers.
     */
    handle->stamp = call LocalTime.get();
    atomic {
      handle->req_state = SS_REQ_STATE_FULL;
      ssc.ssw_num_full++;
      if (ssc.ssw_num_full > ssc.ssw_max_full)
	ssc.ssw_max_full = ssc.ssw_num_full;
    }
    ssc.ssw_in++;
    if (ssc.ssw_in >= SSW_NUM_BUFS)
      ssc.ssw_in = 0;
    call Semaphore.release(&write_sem);
  }


  error_t read_blk_fail(uint32_t blk, uint8_t *buf) {
    error_t err;

    err = call SDread.read(blk, buf);
    if (err) {
      ss_panic(13, err);
      return err;
    }
    return err;
  }

  event void SDread.readDone(uint32_t blk, void *buf, error_t error) {
  }


  command ss_wr_req_t* SSW.get_free_buf_handle() {
    ss_wr_req_t *sswp;

    sswp = ssw_p[ssc.ssw_alloc];
    if (ssc.ssw_alloc >= SSW_NUM_BUFS ||
	ssc.majik_a != SSC_MAJIK_A ||
	ssc.majik_b != SSC_MAJIK_B ||
	sswp->req_state < SS_REQ_STATE_FREE ||
	sswp->req_state >= SS_REQ_STATE_MAX) {
      ss_panic(18, -1);
      return NULL;
    }

    if (sswp->req_state == SS_REQ_STATE_FREE) {
      if (sswp->majik != SS_REQ_MAJIK) {
	ss_panic(19, -1);
	return NULL;
      }
      sswp->stamp = call LocalTime.get();
      sswp->req_state = SS_REQ_STATE_ALLOC;
      ssc.ssw_alloc++;
      if (ssc.ssw_alloc >= SSW_NUM_BUFS)
	ssc.ssw_alloc = 0;
      return sswp;
    }
    ss_panic(20, -1);
    return NULL;
  }


  command uint8_t *SSW.buf_handle_to_buf(ss_wr_req_t *handle) {
    if (!handle || handle->majik != SS_REQ_MAJIK ||
	handle->req_state != SS_REQ_STATE_ALLOC) {
      ss_panic(21, -1);
      return NULL;
    }
    return handle->buf;
  }


  async command void ResourceConfigure.configure() {
    ss_state_t cur_state;

    atomic cur_state = ss_state;
    switch(cur_state) {
      default:
      case SS_STATE_CRASHED:
      case SS_STATE_PWR_UP:
      case SS_STATE_XFER_R:
      case SS_STATE_XFER_W:
	ss_panic(22, cur_state);
	break;

      case SS_STATE_OFF:
	call HW.sd_on();
	atomic ss_state = SS_STATE_PWR_UP;
      case SS_STATE_IDLE:
	call SpiResourceConfigure.configure();
    }
  }


  async command void ResourceConfigure.unconfigure() {
    switch(ss_state) {
      default:
      case SS_STATE_CRASHED:
      case SS_STATE_OFF:
      case SS_STATE_PWR_UP:
      case SS_STATE_XFER_R:
	ss_panic(23, ss_state);
	break;

	/* If IDLE turn the device off and then deconfigure.
	 * If doing a write transfer then leave power on so the
	 * transfer can complete.  The data has already been
	 * sent over to the SD and we are waiting for it to do
	 * the actual write.  Upon conclusion we will have to
	 * reacquire the bus to finish.
	 *
	 * If reading shouldn't have let go.
	 */
      case SS_STATE_IDLE:
	call HW.sd_off();	// and then unconfigure
	ss_state = SS_STATE_OFF;
      case SS_STATE_XFER_W:
	call SpiResourceConfigure.unconfigure();
	break;
    }
  }


  /*
   * Reset_Maybe
   *
   * We try to keep the SD powered in some cases.  If the SD is fresh up
   * from a power on then a reset is needed.  If it is in IDLE the reset
   * can be skipped.
   *
   * returns TRUE if aborted,  FALSE otherwise.
   */

  bool
  ss_reset_maybe() {
    ss_state_t cur_state;
    error_t err;

    atomic cur_state = ss_state;
    if (cur_state != SS_STATE_PWR_UP && cur_state != SS_STATE_IDLE) {
      call Panic.warn(PANIC_SS_RECOV, 25, cur_state, 0, 0, 0);
      atomic cur_state = ss_state = SS_STATE_PWR_UP;
    }

    if(cur_state == SS_STATE_PWR_UP) {
      err = call SDreset.reset();
      if (err) {
	ss_panic(26, err);
	return TRUE;
      }
      atomic ss_state = SS_STATE_IDLE;
    }
    return FALSE;
  }


  event void SSWriter.run(void* arg) {
    ss_wr_req_t* cur_handle;
    error_t err;
    uint16_t delta, num;
    uint32_t dblk_nxt;

    for(;;) {
      call Semaphore.acquire(&write_sem);

      /*
       * if the next out buffer indicates it isn't full then we are seeing
       * the ghost artifact from a race condition between thread and task level
       * The thread loop may have already processed the buffer and now we need
       * to clean up the semaphore.
       *
       * The access of req_state is atomic so shouldn't have a race problem with
       * the task level.
       */
      cur_handle = ssw_p[ssc.ssw_out];
      if (cur_handle->req_state != SS_REQ_STATE_FULL)
	continue;

      /*
       * When running a simple sensor regime (all 1 sec, mag/accel 51mis) and writing out
       * all packets to the serial port, gathering 3 causes a panic.  There isn't enough
       * time for Stream Storage to gain  control.
       */

      if (ssc.ssw_num_full < SSW_GROUP)	// for now gather n up and ship out together
	continue;

      /*
       * We have blocks to write.   If dblk_nxt is 0 then the stream is full.
       * Otherwise, request the mass storage, which handles turning itself on and off.
       * When the grant comes back the device has been turned on and reset has completed.
       */

      dblk_nxt = call FS.get_nxt_blk(FS_AREA_TYPED_DATA);
      if (dblk_nxt != 0) {
	ssw_delay_start = call LocalTime.get();
	call WriteResource.request();		 // this will also turn on the hardware when granted.
	ssw_write_grp_start = call LocalTime.get();
	delta = (uint16_t) (ssw_write_grp_start - ssw_delay_start);
	call LogEvent.logEvent(DT_EVENT_SSW_DELAY_TIME, delta);
	call Trace.trace(T_SSW_DELAY_TIME, delta, 0);
      }

      num = 0;
      for (;;) {
	/*
	 * current buffer needs to be full if we have work to do
	 */
	if (cur_handle->req_state != SS_REQ_STATE_FULL)
	  break;

	if (dblk_nxt != 0) {
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
	  cur_handle->req_state = SS_REQ_STATE_WRITING;
	  atomic ss_state = SS_STATE_XFER_W;
	  w_t0 = call LocalTime.get();
	  err = call SDwrite.write(dblk_nxt, cur_handle->buf);
	  if (err)
	    ss_panic(27, err);
	  num++;
	  w_diff = call LocalTime.get() - w_t0;
	  delta = (uint16_t) w_diff;
	  call LogEvent.logEvent(DT_EVENT_SSW_BLK_TIME, delta);
	  call Trace.trace(T_SSW_BLK_TIME, delta, num);
	}

	cur_handle->stamp = call LocalTime.get();
	cur_handle->req_state = SS_REQ_STATE_FREE;
	ssc.ssw_out++;
	if (ssc.ssw_out >= SSW_NUM_BUFS)
	  ssc.ssw_out = 0;
	ssc.ssw_num_full--;
	if (dblk_nxt != 0) {
	  dblk_nxt = call FS.advance_nxt_blk(FS_AREA_TYPED_DATA);
	  if (dblk_nxt == 0) {
	    /*
	     * advance_nxt_blk returning 0 says we ran off the end of
	     * the file system area.
	     */
	    signal SSF.dblk_stream_full();
	    atomic ss_state = SS_STATE_IDLE;
	    call WriteResource.release();	// will shutdown the hardware
	  }
	}
	cur_handle = ssw_p[ssc.ssw_out];
      }

      delta = (uint16_t) (call LocalTime.get() - ssw_write_grp_start);
      call LogEvent.logEvent(DT_EVENT_SSW_GRP_TIME, delta);
      call Trace.trace(T_SSW_GRP_TIME, delta, num);

      if (dblk_nxt != 0) {
	/*
	 * Only have to release if the stream is active
	 *
	 * This is where to implement OFF_WAIT
	 * For now we just go idle and release
	 */
	atomic ss_state = SS_STATE_IDLE;
	call WriteResource.release(); // will shutdown the hardware
      }
    }
  }


#ifdef notdef
  /*****************************************************************************
   *
   * READING
   *
   */

  command error_t SSR.read_block[uint8_t client_id](uint32_t blk, uint8_t *buf) {
    ss_rd_req_t *rdp;
    uint8_t in_index;

    if (client_id > SSR_CLIENT_MAX) {
      call Panic.panic(PANIC_SS, 80, client_id, 0, 0, 0);
      return FAIL;
    }

    /*
     * handles should be flushed in strict order.  So the next one
     * in should be where in_index points.
     */
    in_index = ssc.ssr_in;
    rdp = ssr_p[in_index];

    /* the next check also catches the null pointer */
    if (!buf || rdp->majik != SS_REQ_MAJIK ||
	rdp->req_state != SS_REQ_STATE_FREE) {
      call Panic.panic(PANIC_SS, 81, (uint16_t) rdp, rdp->majik, rdp->req_state, (uint16_t) buf);
    }

    if (ssc.majik_a != SSC_MAJIK_A || ssc.majik_b != SSC_MAJIK_B)
      call Panic.panic(PANIC_SS, 82, ssc.majik_a, ssc.majik_b, 0, 0);

    rdp->stamp = call LocalTime.get();
    rdp->cid = client_id;
    rdp->blk = blk;
    rdp->buf = buf;
    atomic rdp->req_state = SS_REQ_STATE_READ_REQ;
    ssc.ssr_in++;
    if (ssc.ssr_in >= SSW_NUM_BUFS)
      ssc.ssr_in = 0;
    call Semaphore.release(&read_sem);
    return SUCCESS;
  }

  void signalTask(syscall_t* s) {
    read_block_t* r = s->params;

    if (r->cid > SSR_CLIENT_MAX) {
      call Panic.panic(PANIC_SS, 83, r->cid, 0, 0, 0);
      return;
    }
    signal SSR.read_block_done[r->cid](r->blk, r->buf, r->err);
    call SystemCall.finish(s);
  }
  

  inline void signalClient(uint8_t cid, uint32_t blk, uint8_t *buf, error_t err) {
    syscall_t s;
    read_block_t r;

    r.cid = cid;
    r.blk = blk;
    r.buf = buf;
    r.err = err;
    call SystemCall.start(&signalTask, &s, INVALID_ID, &r);
  }
  

  default event void SSR.read_block_done[uint8_t client_id](uint32_t blk, uint8_t *buf, error_t err) {}


  event void SSReader.run(void* arg) {
    ss_rd_req_t* cur_handle;
    error_t err;

    for(;;) {
      call Semaphore.acquire(&read_sem);

      //Get the current req handle
      cur_handle = ssr_p[ssc.ssr_out];

      call ReadResource.request();
      if (ss_reset_maybe()) {
	/*
	 * Actually, fix this so it errors out the client
	 */
	continue;			/* if failed keep looking for work. */
      }

      atomic ss_state = SS_STATE_XFER_R;
      for(;;) {

	/*
	 * Actually do the read.
	 */
	if (cur_handle->req_state == SS_REQ_STATE_FREE)
	  break;

	//If we are not in the epxected possible states, panic
	if (cur_handle->req_state != SS_REQ_STATE_READ_REQ)
	  ss_panic(30, -1);

	cur_handle->stamp = call LocalTime.get();
	cur_handle->req_state = SS_REQ_STATE_READING;
	err = call SDread.read(cur_handle->blk, cur_handle->buf);
	if (err)
	  ss_panic(31, err);
 
	cur_handle->stamp = call LocalTime.get();
	cur_handle->req_state = SS_REQ_STATE_FREE;

	signalClient(cur_handle->cid, cur_handle->blk, cur_handle->buf, SUCCESS);

	ssc.ssr_out++;
	if (ssc.ssr_out >= SSR_NUM_REQS)
	  ssc.ssr_out = 0;
	cur_handle = ssr_p[ssc.ssr_out];
      }

      atomic ss_state = SS_STATE_IDLE;
      call ReadResource.release();    //Shouldn't this be on the outside of this for-loop?
      //We have that 'continue' statement outisde of this for-loop
    }
  }
#endif


#ifdef notdef
  void ss_machine(msg_event_t *msg) {
    uint8_t     *buf;
    ss_wr_req_t	*ss_handle;
    ss_timer_data_t mtd;
    mm_time_t       t;
    sd_rtn	 err;

    switch(ss_state) {
      case SS_STATE_OFF:
      case SS_STATE_IDLE:
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
	 * Next one expected is ssc.ssw_in.
	 */
	ss_handle = (ss_wr_req_t *) (buf - SS_HANDLE_OFFSET);
	if (ss_handle->majik != SS_REQ_MAJIK)
	  panic();
	if (ss_handle->req_state != SS_REQ_STATE_ALLOC)
	  panic();

	if (&ssw_handles[ssc.ssw_in] != ss_handle)
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
	if (ssc.ssw_in != ssc.ssw_out)
	  panic();
#endif

	ss_handle->req_state = SS_REQ_STATE_FULL;
	ssc.ssw_num_full++;
	if (ssc.ssw_num_full > ssc.ssw_max_full)
	  ssc.ssw_max_full = ssc.ssw_num_full;
	ssc.ssw_in++;
	if (ssc.ssw_in >= SSW_NUM_BUFS)
	  ssc.ssw_in = 0;

	/*
	 * We are ready to hit the h/w.  1st check to see if the h/w
	 * is busy.  If so then bail early.  However if we've been
	 * busy too long, then take it anyway and inform the other
	 * subsystems.
	 *
	 * Because of multiplexing we may have buffers that are backed
	 * up.  The buffer that just came in may not be the one that
	 * needs to go out next.  Once we get the hardware, make sure
	 * to send out the next one that should go.  ssc.ssw_out
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
	  if (ssc.ssw_num_full < SS_CRITICAL_BUFS)
	    return;

	  if (us1_select(US1_NONE, FALSE))
	    panic();

	  /*
	   * tell other subsystems that they had the h/w yanked away.
	   */
	}

	if (ss_state == SS_STATE_OFF) {
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
	ss_handle = &ssw_handles[ssc.ssw_out];
	if (ss_handle->req_state != SS_REQ_STATE_FULL)
	  panic();

	time_get_cur(&t);
	add_times(&t, &ss_write_timeout_delay);
	mtd.which = SS_TIME_WRITE_TIMEOUT;
	if (ss_wto_handle != TIMER_HANDLE_FREE)
	  panic();
	ss_wto_handle = timer_set(&t, ss_write_timeout, &mtd);
	ss_handle->req_state = SS_REQ_STATE_WRITING;
	err =
	  sd_start_write(NULL, dblk_nxt, ss_handle->buf);
	if (err)
	  panic();
	ss_state = SS_STATE_XFER_W;
	DMA0CTL_bit.DMAIE = 1;
	return;
	      
      case SS_STATE_XFER_W:
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
	  ss_handle = (ss_wr_req_t *) (buf - SS_HANDLE_OFFSET);
	  if (ss_handle->majik != SS_REQ_MAJIK)
	    panic();
	  if (ss_handle->req_state != SS_REQ_STATE_ALLOC)
	    panic();
	  if (&ssw_handles[ssc.ssw_in] != ss_handle)
	    panic();

	  /*
	   * Switch to Full, bump the next expected and
	   * that's all she wrote.
	   */
	  ss_handle->req_state = SS_REQ_STATE_FULL;
	  ssc.ssw_num_full++;
	  if (ssc.ssw_num_full > ssc.ssw_max_full)
	    ssc.ssw_max_full = ssc.ssw_num_full;
	  ssc.ssw_in++;
	  if (ssc.ssw_in >= SSW_NUM_BUFS)
	    ssc.ssw_in = 0;
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
	  if (ssw_handles[ssc.ssw_out].req_state != SS_REQ_STATE_WRITING)
	    panic();
	  ssw_handles[ssc.ssw_out].req_state = SS_REQ_STATE_FREE;
	  ssc.ssw_num_full--;
	  ssc.ssw_out++;
	  if (ssc.ssw_out >= SSW_NUM_BUFS)
	    ssc.ssw_out = 0;
	  dblk_nxt++;
	  if (dblk_nxt >= ssc.dblk_end)
	    panic();

	  /*
	   * See if the next buffer needs to be written.
	   */
	  if (ssw_handles[ssc.ssw_out].req_state == SS_REQ_STATE_FULL) {
	    time_get_cur(&t);
	    add_times(&t, &ss_write_timeout_delay);
	    mtd.which = SS_TIME_WRITE_TIMEOUT;
	    if (ss_wto_handle != TIMER_HANDLE_FREE)
	      panic();
	    ss_wto_handle = timer_set(&t, ss_write_timeout, &mtd);
	    ssw_handles[ssc.ssw_out].req_state = SS_REQ_STATE_WRITING;
	    err =
	      sd_start_write(NULL, dblk_nxt, ssw_handles[ssc.ssw_out].buf);
	    if (err)
	      panic();
	    DMA0CTL_bit.DMAIE = 1;
	    return;
	  }

	  /*
	   * Not Full.  For now just go idle.  and dump the h/w so
	   * a different subsystem can get it.
	   */
	  ss_state = SS_STATE_IDLE;
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
    if (ssc.ssw_out >= SSW_NUM_BUFS ||
	(ssw_handles[ssc.ssw_out].req_state != SS_REQ_STATE_WRITING) ||
	(ss_wto_handle >= N_TIMERS))
      panic();
    mm_timer_delete(ss_wto_handle, ss_write_timeout);
    ss_wto_handle = TIMER_HANDLE_FREE;
    sched_enqueue(TASK_MS, msg_ss_DMA_Complete, MSG_ADDR_MS, (msg_param_t) (&ssw_handles[ssc.ssw_out]));
    __low_power_mode_off_on_exit();
  }

#endif

}
