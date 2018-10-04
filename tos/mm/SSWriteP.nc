/*
 * Copyright (c) 2008, 2010, 2017-2018, Eric B. Decker
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 * See COPYING in the top level directory of this source tree.
 *
 * Contact: Eric B. Decker <cire831@gmail.com>
 */

/*
 * Stream Storage Write - write sequential blocks to a contiguous data
 * area.  The area is considered a file and managed by the file system
 * such as it is.  Basically, the file system simply tells us the limits
 * of file (start/end) and what block to write next.  The file system
 * maintains the current block.
 *
 * The data storage area contains typed data described by typed_data.h.
 *
 * SSWrite provides a pool of buffers to its users and manages when those
 * buffers get written to the SD.
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
 * Power management of the SD is handled by the SD driver.  SSWrite
 * will request the h/w, and when granted, the SD will be powered up and
 * out of reset.  When StreamStorage runs out of work, it will release
 * the h/w which will determine whether to turn the device off or not.
 * The device will be turned off if there are no other clients waiting.
 *
 * flush_all is called to push any pending buffers out to the SD.  This
 * is called from Collect on a SysReboot.shutdown_flush and uses SDsa
 * the stand alone (run to completion) interface to the SD driver.
 */

#include <panic.h>
#include <platform_panic.h>
#include "stream_storage.h"

uint32_t w_t0, w_diff;

#ifndef PANIC_SS
enum {
  __pcode_ss = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_SS __pcode_ss
#endif


module SSWriteP {
  provides {
    interface Init;
    interface SSWrite       as SSW;
    interface StreamStorage as SS;
  }
  uses {
    interface SDwrite;
    interface SDsa;
    interface DblkManager;
    interface Resource as SDResource;
    interface Panic;
    interface LocalTime<TMilli>;
    interface Trace;
    interface CollectEvent;
    interface Collect;
  }
}

implementation {

  ss_wr_buf_t ssw_handles[SSW_NUM_BUFS];
  ss_wr_buf_t * const ssw_p[SSW_NUM_BUFS] = {
    &ssw_handles[0],
    &ssw_handles[1],
    &ssw_handles[2],
    &ssw_handles[3],
    &ssw_handles[4],
    &ssw_handles[5],
    &ssw_handles[6],
    &ssw_handles[7],
    &ssw_handles[8],
    &ssw_handles[9],
  };

#if SSW_NUM_BUFS != 10
#warning "SSW_NUM_BUFS is other than 10"
#endif

  norace ss_control_t ssc;              /* all global control cells */


  /*
   * instrumentation for measuring how long things take.
   */
  uint32_t ssw_delay_start;             // how long are we held off?
  uint32_t ssw_write_grp_start;         // when we start the write of the group.

#define ss_panic(where, arg) do { call Panic.panic(PANIC_SS, where, arg, 0, 0, 0); } while (0)

  void flush_buffers(void) {
    while (ssc.cur_handle->buf_state == SS_BUF_STATE_FULL) {
      ssc.cur_handle->stamp = call LocalTime.get();
      ssc.cur_handle->buf_state = SS_BUF_STATE_FREE;
      memset(ssc.cur_handle->buf, 0, SD_BLOCKSIZE);
      ssc.ssw_out++;
      if (ssc.ssw_out >= SSW_NUM_BUFS)
        ssc.ssw_out = 0;
      ssc.ssw_num_full--;
      ssc.cur_handle = ssw_p[ssc.ssw_out];
    }
    ssc.cur_handle = NULL;
  }


  command error_t Init.init() {
    uint16_t i;

    ssc.majik_a     = SSC_MAJIK;
    ssc.majik_b     = SSC_MAJIK;

    /* ssw_p[x]->buf_state starts in FREE (0) */
    for (i = 0; i < SSW_NUM_BUFS; i++)
      ssw_p[i]->majik = SS_BUF_SANE;

    /* no need to zero the buffer, done by start up code */
    return SUCCESS;
  }


  /*
   * SSWrite.buffer_full()
   *
   * called from the client to indicate that it has
   * filled the buffer.
   *
   * The main SSWriter task will be kicked if current state is IDLE and
   * we have at least SSW_GROUP buffers.
   */

  task void SSWriter_task();

  command void SSW.buffer_full(ss_wr_buf_t *handle) {
    ss_wr_buf_t *sswp;
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
        handle->majik != SS_BUF_SANE ||
        handle->buf_state != SS_BUF_STATE_ALLOC) {
      call Panic.panic(PANIC_SS, 11, (parg_t) handle, handle->majik,
                       handle->buf_state, (parg_t) sswp);
    }

    if (ssc.majik_a != SSC_MAJIK || ssc.majik_b != SSC_MAJIK)
      call Panic.panic(PANIC_SS, 12, ssc.majik_a, ssc.majik_b, 0, 0);

    handle->stamp = call LocalTime.get();
    handle->buf_state = SS_BUF_STATE_FULL;
    ssc.ssw_num_full++;
    if (ssc.ssw_num_full > ssc.ssw_max_full)
      ssc.ssw_max_full = ssc.ssw_num_full;
    if (ssc.state == SSW_IDLE && ssc.ssw_num_full >= SSW_GROUP)
      post SSWriter_task();
    ssc.ssw_in++;
    if (ssc.ssw_in >= SSW_NUM_BUFS)
      ssc.ssw_in = 0;
  }


  command ss_wr_buf_t* SSW.get_free_buf_handle() {
    ss_wr_buf_t *sswp;

    sswp = ssw_p[ssc.ssw_alloc];
    if (ssc.ssw_alloc >= SSW_NUM_BUFS ||
        ssc.majik_a != SSC_MAJIK ||
        ssc.majik_b != SSC_MAJIK ||
        sswp->buf_state < SS_BUF_STATE_FREE ||
        sswp->buf_state >= SS_BUF_STATE_MAX)
      ss_panic(13, ssc.ssw_alloc);

    if (sswp->buf_state == SS_BUF_STATE_FREE) {
      if (sswp->majik != SS_BUF_SANE)
        ss_panic(14, sswp->majik);

      sswp->stamp = call LocalTime.get();
      sswp->buf_state = SS_BUF_STATE_ALLOC;
      ssc.ssw_alloc++;
      if (ssc.ssw_alloc >= SSW_NUM_BUFS)
        ssc.ssw_alloc = 0;
      return sswp;
    }
    ss_panic(15, -1);
    return NULL;
  }


  command uint8_t *SSW.buf_handle_to_buf(ss_wr_buf_t *handle) {
    if (!handle || handle->majik != SS_BUF_SANE ||
        handle->buf_state != SS_BUF_STATE_ALLOC)
      ss_panic(16, (parg_t) handle);

    return handle->buf;
  }


  /*
   * eof_offset: return file offset of current end of the stream.
   *
   * Dblk streaming only lays down records (dblks).  The eof_offset
   * then is the offset of the next record to be written.
   *
   * DM.dblk_nxt_offset() will give us the offset of where dblk_nxt
   * currently resides.  If the stream is full, this will be 0 and
   * we are done.
   *
   * We also need to account for any buffers in SSW holding data.
   * And we need to ask Collect to see if it is currently working
   * on a buffer.  Collect will tell us where the next record
   * will get layed down (buf_offset).
   */
  async command uint32_t SS.eof_offset() {
    uint32_t offset;

    offset = call DblkManager.dblk_nxt_offset();
    if (!offset)
      return offset;                    /* 0 */
    offset += ssc.ssw_num_full * SD_BLOCKSIZE;
    offset += call Collect.buf_offset();
    return offset;
  }


  async command uint32_t SS.committed_offset() {
    return call DblkManager.dblk_nxt_offset();
  }


  /*
   * get_temp_buf: return one of the SSW's buffers
   *
   * Intended to be used while the system is single threaded by a user
   * that needs to access the SD and needs a buffer.
   */
  async command uint8_t *SSW.get_temp_buf() {
    uint32_t i;

    for (i = 0; i < SSW_NUM_BUFS; i++)
      if (ssw_p[i]->buf_state == SS_BUF_STATE_FREE)
        return ssw_p[i]->buf;
    ss_panic(17, i);
    return NULL;
  }


  /*
   * Core Stream Storage Writer
   *
   * The SSWriter_task is what performs the main function of the Stream writer.
   *
   * The task gets posted anytime a buffer becomes available.  The writer stays
   * idle until SSW_GROUP buffers are available.  This amortizes any start up
   * cost of powering the SD up across that many buffers.  We assume that the
   * SD is off.  This could be changed easily by allowing a peek at the SD state
   * and starting the write up if the SD is already on.  This would reduce the
   * amount of pending data.  ie.  if we crash, right now we lose any data that
   * hasn't been written out yet.
   *
   * IDLE: not doing anything yet, possibly collecting buffers.
   *       when SSW_GROUP buffers have been collected start writing.  request
   *       the h/w.
   *
   * REQUESTED: h/w has been requested.  waiting for the grant.
   *
   * WRITING: buffers are being sent to the h/w.  waiting for writeDone event.
   */

  task void SSWriter_task() {
    error_t err;

    /*
     * This task should only get kicked if not doing anything
     */
    if (ssc.state != SSW_IDLE || ssc.ssw_num_full < SSW_GROUP)
      call Panic.panic(PANIC_SS, 18, ssc.state, ssc.ssw_num_full, 0, 0);

    ssc.cur_handle = ssw_p[ssc.ssw_out];
    if (ssc.cur_handle->buf_state != SS_BUF_STATE_FULL)
      ss_panic(19, ssc.cur_handle->buf_state);

    /*
     * When running a simple sensor regime (all 1 sec, mag/accel 51mis) and writing out
     * all packets to the serial port, gathering 3 causes a panic.  There isn't enough
     * time for the StreamStorage thread to gain  control.
     *
     * Verify that this is still a problem when using event based and task based StreamStorage
     * The above shouldn't be a problem with full event based.
     */

    /*
     * We have blocks to write.
     * ssc.dblk being zero denotes the stream is full.  Bail.
     * non-zero, request the h/w.
     */

    if ((ssc.dblk = call DblkManager.get_dblk_nxt()) == 0) {
      /*
       * shut down.  always just free any incoming buffers.
       */
      flush_buffers();
      return;
    }

    /*
     * something to actually write out to h/w.
     */
    ssw_delay_start = call LocalTime.get();
    ssc.state = SSW_REQUESTED;

    /* SDResource.request will all turn on the SD h/w when granted */
    if ((err = call SDResource.request()))
      ss_panic(20, err);
  }


  event void SDResource.granted() {
    error_t  err;

    if (ssc.cur_handle->buf_state != SS_BUF_STATE_FULL)
      call Panic.panic(PANIC_SS, 21, (parg_t) ssc.cur_handle,
                       (parg_t) ssc.cur_handle->buf_state, 0, 0);

    if (ssc.dblk == 0)                  /* shouldn't have asked if no where to write */
      ss_panic(22, ssc.state);

    w_t0 = call LocalTime.get();
    ssw_write_grp_start = w_t0;
    ssc.cur_handle->stamp = w_t0;
    ssc.cur_handle->buf_state = SS_BUF_STATE_WRITING;
    ssc.state = SSW_WRITING;
    err = call SDwrite.write(ssc.dblk, ssc.cur_handle->buf);
    if (err)
      ss_panic(23, err);
  }


  event void SDwrite.writeDone(uint32_t blk, uint8_t *buf, error_t err) {

    if (err || blk != ssc.dblk || ssc.cur_handle->buf_state != SS_BUF_STATE_WRITING)
      call Panic.panic(PANIC_SS, 24, err, blk, ssc.dblk, ssc.cur_handle->buf_state);

    ssc.cur_handle->stamp = call LocalTime.get();
    ssc.cur_handle->buf_state = SS_BUF_STATE_FREE;
    memset(ssc.cur_handle->buf, 0, SD_BLOCKSIZE);
    ssc.ssw_out++;
    if (ssc.ssw_out >= SSW_NUM_BUFS)
      ssc.ssw_out = 0;
    ssc.cur_handle = ssw_p[ssc.ssw_out];                /* point to nxt buf */
    ssc.ssw_num_full--;
    signal SS.dblk_advanced(blk);                       /* tell what we last did */
    if ((ssc.dblk = call DblkManager.adv_dblk_nxt()) == 0) {
      /*
       * adv_nxt_blk returning 0 says we ran off the end of
       * the file system area.
       */
      signal SS.dblk_stream_full();
      flush_buffers();
      ssc.state = SSW_IDLE;
      if (call SDResource.release())
        ss_panic(25, 0);
      return;
    }

    if (ssc.cur_handle->buf_state == SS_BUF_STATE_FULL) {
      /*
       * more work to do, stay in SSW_WRITING.
       */
      w_t0 = call LocalTime.get();
      ssc.cur_handle->stamp = call LocalTime.get();
      ssc.cur_handle->buf_state = SS_BUF_STATE_WRITING;
      err = call SDwrite.write(ssc.dblk, ssc.cur_handle->buf);
      if (err)
        ss_panic(26, err);
      return;
    }
    w_t0 = call LocalTime.get();
    w_diff = w_t0 - ssw_write_grp_start;

    ssc.state = SSW_IDLE;
    if (call SDResource.release())
      ss_panic(27, 0);
  }


  /*
   * flush all pending SSW buffers
   *
   * 1) flush any FULL buffers
   * 2) If there is an ALLOC'd buffer with something in it,
   *    also write that too.  (you like that also too?)
   *    Collect is responsible for filling in required
   *    fields in the ALLOC'd buffer and then kicking SSW.flush_all()
   *
   * we take pains not to tweak memory too much.
   */
  async command void SSW.flush_all() {
    ss_wr_buf_t *handle;
    uint8_t num_full, idx;
    uint32_t dblk;

    /*
     * has the control structure been initialized?
     * nope ->  bail
     */
    if (ssc.majik_a != SSC_MAJIK || ssc.majik_b != SSC_MAJIK)
      return;
    if (!call SDsa.inSA()) {
      if (call SDsa.reset())
        return;
    }

    idx = ssc.ssw_out;
    num_full = ssc.ssw_num_full;

    /* too many, we be gone */
    if (num_full > SSW_NUM_BUFS)
      return;
    dblk = call DblkManager.get_dblk_nxt();
    while (num_full) {
      handle = ssw_p[idx];
      if (dblk == 0)                    /* any unexpected, just bail */
        return;
      if (handle->majik != SS_BUF_SANE ||
          handle->buf_state != SS_BUF_STATE_FULL)
        return;                         /* that's weird, somethings wrong */
      call SDsa.write(dblk, handle->buf);
      idx++;
      if (idx >= SSW_NUM_BUFS)
        idx = 0;
      dblk = call DblkManager.adv_dblk_nxt();

      /*
       * flush_all is a shutdown/reboot kind of thing.  We don't signal
       * SS.dblk_advanced(last);
       */

      num_full--;
    }
    ssc.ssw_num_full = 0;
    ssc.ssw_out = idx;

    /*
     * We have flushed any buffers that are FULL.  We also need to flush
     * the pending buffer that the Collector is currently filling if any.
     */
    if (idx != ssc.ssw_in)              /* should be next in from collector */
      return;                           /* stop what we are doing, if not   */
    handle = ssw_p[idx];
    if (dblk == 0)                      /* if no where to go, bail */
      return;
    if (handle->majik != SS_BUF_SANE ||
        handle->buf_state != SS_BUF_STATE_ALLOC)
      return;

    /*
     * If the buffer is ALLOC'd then the Collector has gotten it and has
     * definitely put something into it.  Just write it out.
     */
    call SDsa.write(dblk, handle->buf);
  }


  command uint32_t SS.get_dblk_low() {
    return call DblkManager.get_dblk_low();
  }


  command uint32_t SS.get_dblk_high() {
    return call DblkManager.get_dblk_high();
  }


  /*
   * StreamStorage.where(): return information where a given file
   *    offset lives. assume we want at least one byte.
   *
   * input:     context
   *            offset          the file offset we are looking for.
   *            *lenp           pointer for length available. (output)
   *            *blk_offsetp    pointer for offset of block returned (output)
   *            **bufp          pointer to buffer pointer (output)
   *
   * output:    *lenp           length available.
   *            *blk_offsetp    offset pointer (output)
   *            **bufp          if in memory, where offset lives (output)
   *
   * return:    0               offset past eof.
   *            blk_id          blk_id corresponding to offset requested
   *                            if >= dblk_nxt then offset is cached.  *bufp
   *                            set to non-null.
   */

  command uint32_t SS.where(uint32_t context, uint32_t offset, uint32_t *lenp,
                            uint32_t *blk_offsetp, uint8_t **bufp) {
    uint32_t dblk_low, dblk_nxt;
    uint32_t rel_blk;                   /* relative block id    */
    uint32_t blk_id;                    /* absolute block id    */
    uint32_t idx;                       /* buffer index, cached */

    if (!lenp || !blk_offsetp || !bufp)
      ss_panic(28, 0);

    *lenp = 0;
    *blk_offsetp = 0;
    *bufp = NULL;

    /* past eof, just bail */
    if (offset >= call SS.eof_offset())
      return 0;

    dblk_low = call DblkManager.get_dblk_low();
    dblk_nxt = call DblkManager.get_dblk_nxt();
    rel_blk  = offset >> SD_BLOCKSIZE_NBITS;
    blk_id   = rel_blk + dblk_low;

    *lenp = SD_BLOCKSIZE;
    *blk_offsetp = rel_blk << SD_BLOCKSIZE_NBITS;

    if (offset < call DblkManager.dblk_nxt_offset())
      return blk_id;

    /*
     * not on disk, can be inside one of the full buffers or potentially in the
     * ALLOC'd buffer that Collect is using.  If in the ALLOC buffer we will
     * ask Collect to find out how far into the buffer it has gone and adjust
     * the size returned accordingly.
     *
     * first figure out which block after the last committed block.  dblk_nxt
     * is the block that will be written next and will be in the first out
     * buffer in SSW.
     *
     * we want to find the SSW index that corresponds to the offset we are
     * looking for.
     */
    idx = blk_id - dblk_nxt;            /* how many past the last commit */
    idx += ssc.ssw_out;                 /* and figure out where in SSW   */
    if (idx >= SSW_NUM_BUFS)            /* adjust for wrap               */
      idx -= SSW_NUM_BUFS;
    *bufp = ssw_handles[idx].buf;

    /* full buffers (lenp set above), unless ALLOC buffer */
    if (idx == ssc.ssw_in)              /* alloc buffer? */
      *lenp = call Collect.buf_offset();
    return blk_id;
  }


  default event void SS.dblk_stream_full()          { }
  default event void SS.dblk_advanced(uint32_t last) { }

        event void Collect.collectBooted() { }
        event void Collect.resyncDone(error_t err, uint32_t offset) { }
  async event void Panic.hook() { }
}
