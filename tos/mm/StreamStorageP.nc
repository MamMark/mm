/*
 * Copyright (c) 2008, 2010 - Eric B. Decker
 * All rights reserved.
 *
 * StreamStorage.nc - write/read sequential blocks to/from
 * a contiguous data area.  The area is considered a file
 * and managed by the file system such as it is.
 *
 * The principal interface provided by StreamStorage is writing sequential
 * blocks to the Typed Data storage area.  The file system is queried to
 * determine what block to write next.
 *
 * SSW (StreamStorageWriter) provides a pool of buffers to its users and manages
 * when those buffers get written to the SD.
 *
 * The calling user of Reader provides the buffer.
 *
 * Overview:
 *
 * Previous implementations of StreamStorage were thread based because
 * the SD driver was run to completion and could take a fairly long time
 * to complete operations.
 *
 * This implementation is fully event driven and uses the split phase SD
 * driver.
 *
 * Power management of the SD is handled by the SD driver.  StreamStorage
 * will request the h/w, and when granted, the SD will be powered up and
 * out of reset.  When StreamStorage runs out of work, it will release
 * the h/w which will determine whether to turn the device off or not.
 */

#include "stream_storage.h"

uint32_t w_t0, w_diff;

typedef enum {
  SSW_IDLE	= 0,
  SSW_REQUESTED,
  SSW_WRITING,
  SSW_RELEASED,
} ssw_state_t;


module StreamStorageP {
  provides {
    interface Init;
    interface StreamStorageWrite as SSW;
    interface StreamStorageFull  as SSF;
  }
  uses {
    interface SDwrite;
    interface FileSystem as FS;
    interface Resource as WriteResource;
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

  ssw_state_t  ssw_state;		 // current state of writer machine (2 bytes)
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

    ssw_state       = SSW_IDLE;

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

  task void SSWriter_task();

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
      if (ssw_state == SSW_IDLE)
	post SSWriter_task();
    }
    ssc.ssw_in++;
    if (ssc.ssw_in >= SSW_NUM_BUFS)
      ssc.ssw_in = 0;
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


  command uint8_t *SSW.get_temp_buf() {
    return(ssw_p[0]->buf);
  }


#ifdef notdef
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
#endif


  task void SSWriter_task() {
    ss_wr_req_t* cur_handle;
    error_t err;
    uint16_t delta, num;
    uint32_t dblk_nxt;

    /*
     * This task should only be activated if the Writer is IDLE and a buffer
     * has gone full.  The first buffer had better be full.
     */
    if (ssw_state != SSW_IDLE) {
      ss_panic(22, ssw_state);
      return;
    }
      
    cur_handle = ssw_p[ssc.ssw_out];
    if (cur_handle->req_state != SS_REQ_STATE_FULL) {
      ss_panic(22, cur_handle->req_state);
      return;
    }

    /*
     * When running a simple sensor regime (all 1 sec, mag/accel 51mis) and writing out
     * all packets to the serial port, gathering 3 causes a panic.  There isn't enough
     * time for the StreamStorage thread to gain  control.
     *
     * Verify that this is still a problem when using event based and task based StreamStorage
     * The above shouldn't be a problem with full event based.
     */

    if (ssc.ssw_num_full < SSW_GROUP)	// for now gather n up and ship out together
      return;

    /*
     * We have blocks to write.
     * dblk_nxt being zero denotes the stream is full.  Bail.
     * dblk_nxt non-zero, request the h/w.
     */

    dblk_nxt = call FS.get_nxt_blk(FS_AREA_TYPED_DATA);
    if (dblk_nxt == 0) {
      /*
       * shut down.  always just free any incoming buffers.
       */
      return;
    }

    /*
     * something to actually write out to h/w.
     */
    ssw_delay_start = call LocalTime.get();
    ssw_write_grp_start = call LocalTime.get();
    call WriteResource.request();		 // this will also turn on the hardware when granted.
    ssw_state = SSW_REQUESTED;
  }


  event void WriteResource.granted() {
    delta = (uint16_t) (ssw_write_grp_start - ssw_delay_start);
    call LogEvent.logEvent(DT_EVENT_SSW_DELAY_TIME, delta);
    call Trace.trace(T_SSW_DELAY_TIME, delta, 0);

    num = 0;
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
      ssw_state = SSW_WRITING;
      w_t0 = call LocalTime.get();
      err = call SDwrite.write(dblk_nxt, cur_handle->buf);
    }
  }

  /* needs to start up the next buffer too! */

  event void SDwrite.writeDone() {
    if (err)
      ss_panic(27, err);
    num++;
    w_diff = call LocalTime.get() - w_t0;
    delta = (uint16_t) w_diff;
    call LogEvent.logEvent(DT_EVENT_SSW_BLK_TIME, delta);
    call Trace.trace(T_SSW_BLK_TIME, delta, num);
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
	ssw_state = SSW_IDLE;
	call WriteResource.release();	// will shutdown the hardware
	return;
      }
    }
    cur_handle = ssw_p[ssc.ssw_out];

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
      ssw_state = SSW_IDLE;
      call WriteResource.release(); // will shutdown the hardware
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
}
