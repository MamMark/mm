/*
 * CollectP.nc - data collector (record managment) interface
 * between data collection and mass storage.
 *
 * Copyright 2008, 2014, 2017: Eric B. Decker
 * All rights reserved.
 * Mam-Mark Project
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

/*
 * Collect/RecSum: Record Checksum Implementation
 *
 * Collect records and kick them to Stream Storage.
 *
 * Originally, we provided for data integrity by a single checksum
 * and a sequence number on each sector.  This however, requires
 * a three level implementation to recover split records.
 *
 * Replacing this with a per record checksum results in both the sector
 * checksum and sequence number disappearing.  This greatly simplifies
 * the software implementation and collapses the layers into one.
 *
 * See typed_data.h for details on how the headers are layed out.
 *
 * Mass Storage block size is 512.  If this changes the tag is severly
 * bolloxed as this number is spread a number of different places.  Fucked
 * but true.  Collect uses the entire underlying sector.  This is
 * SD_BLOCKSIZE.  There is no point in abstracting this at the
 * StreamStorage layer.  SD block size permeats too many places.  And it
 * doesn't change.
 *
 * Data associated with a given header however can be split across sector
 * boundaries but is limited to DT_MAX_DLEN.  (defined in typed_data.h).
 *
 * Collect is responsible for laying down REBOOT records on the way up and
 * SYNC records at appropriate times/events.  We primarily lay down SYNCs
 * based on how many sectors (buffers) have been written.  In addition, as
 * a fail safe, we also start a timer after any SYNC as been written.  If
 * the timer expires, we lay down a SYNC.
 *
 * Collect is responsible for managing prev_sync file offsets.  This a
 * combination of blk_id and byte offset within the buffer of the SYNC or
 * REBOOT being lay'd down.
 */

#include <typed_data.h>
#include <image_info.h>
#include <overwatch.h>
#include <stream_storage.h>
#include <sd.h>


/*
 * Data Collector (dc) control structure
 *
 * The data collector is the record marshaller and lays records down into
 * the underlying SD buffers that Stream Storage (SSW) gives us.
 *
 * remaining:           number of bytes still remaining in current buffer
 * handle:              keeper of the current SSW handle
 * cur_buf:             extracted start of the buffer from the handle
 * cur_ptr:             where in the current buffer we be
 *
 * cur_recnum:          last recnum used.
 * last_sync_offset:    file offset of last REBOOT/SYNC laid down
 * bufs_to_next_sync:   number of buffers/sectors before we do next sync

 * DblkManager is responsible for keeping track of where in the Data Stream
 * we are.
 */
typedef struct {
  uint16_t     majik_a;

  uint16_t     remaining;
  ss_wr_buf_t *handle;
  uint8_t     *cur_buf;
  uint8_t     *cur_ptr;

  uint32_t     cur_recnum;
  uint32_t     last_sync_offset;        /* file offset */
  uint16_t     bufs_to_next_sync;

  uint16_t     majik_b;
} dc_control_t;

#define DC_MAJIK 0x1008


extern image_info_t image_info;
extern ow_control_block_t ow_control_block;


module CollectP {
  provides {
    interface Boot as Booted;           /* out boot */
    interface Collect;
    interface Init;
    interface CollectEvent;
  }
  uses {
    interface Boot;                     /* in boot in sequence */
    interface Boot as SysBoot;          /* use at end of System Boot initilization */
    interface Timer<TMilli> as SyncTimer;
    interface OverWatch;

    interface SSWrite as SSW;
    interface Panic;
    interface DblkManager;
    interface SysReboot @atleastonce();
    interface LocalTime<TMilli>;
  }
}

implementation {

  norace dc_control_t dcc;


  /*
   * update_sync_offset
   * update the last know sync file offset.
   */
  void update_sync_offset() {
    uint32_t blk_offset;
    uint32_t buf_offset;

    /* get the file offset of the current block */
    buf_offset = 0;
    blk_offset = call SSW.block_offset();
    if (!blk_offset) {
      dcc.last_sync_offset = 0;
      return;
    }

    /*
     * if we have a non-zero buf pointer we still have a live buffer.
     * It hasn't been handed over to stream storage and won't be
     * accounted for by SSW.block_offset.
     *
     * dcc.remaining will always tell the story and may be 0.
     */
    if (dcc.cur_buf)
      buf_offset = SD_BLOCKSIZE - dcc.remaining;
    blk_offset += buf_offset;
    dcc.last_sync_offset = blk_offset;
  }


  void write_version_record() {
    dt_version_t  v;
    dt_version_t *vp;

    vp = &v;
    vp->len     = sizeof(v) + sizeof(image_info_t);
    vp->dtype   = DT_VERSION;
    vp->base    = call OverWatch.getImageBase();
    vp->pad     = 0;
    call Collect.collect((void *) vp, sizeof(dt_version_t),
                         (void *) &image_info, sizeof(image_info_t));
  }


  void write_sync_record() {
    dt_sync_t  s;
    dt_sync_t *sp;

    sp = &s;
    sp->len = sizeof(s);
    sp->dtype = DT_SYNC;
    sp->sync_majik = SYNC_MAJIK;
    sp->prev_sync  = dcc.last_sync_offset;
    sp->pad0 = sp->pad1 = 0;
    update_sync_offset();
    call Collect.collect((void *) sp, sizeof(dt_sync_t), NULL, 0);
  }


  void write_reboot_record() {
    dt_reboot_t  r;
    dt_reboot_t *rp;

    rp = &r;
    rp->len = sizeof(r) + sizeof(ow_control_block_t);
    rp->dtype = DT_REBOOT;
    rp->sync_majik = SYNC_MAJIK;
    rp->prev_sync  = dcc.last_sync_offset;
    rp->dt_h_revision = DT_H_REVISION;  /* which version of typed_data */
    rp->base = call OverWatch.getImageBase();
    rp->pad0 = rp->pad1 = 0;
    update_sync_offset();
    call Collect.collect((void *) rp, sizeof(r),
                         (void *) &ow_control_block,
                         sizeof(ow_control_block_t));
    call OverWatch.clearReset();        /* clears owcb copies */

    /* clear resetable faults */
    call OverWatch.clrFault(OW_FAULT_LOW_PWR);
  }


  /*
   * Always write the reboot record first.
   *
   * This is the very first record (REBOOT) after we've come up.
   * This will ALWAYS be the first record written to the very
   * first sector that DblkManager has found for where the Data
   * Stream will restart.
   */
  event void Boot.booted() {
    write_reboot_record();
    write_version_record();
    nop();                              /* BRK */
    signal Booted.booted();
  }


  task void collect_sync_task() {
    /*
     * update down counters first, to avoid getting SYNCs very close
     * together.
     */
    dcc.bufs_to_next_sync = SYNC_MAX_SECTORS;
    call SyncTimer.stop();
    write_sync_record();
    call SyncTimer.startOneShot(SYNC_PERIOD);
  }


  event void SysBoot.booted() {
    call SyncTimer.startOneShot(SYNC_PERIOD);
  }


  event void SyncTimer.fired() {
    post collect_sync_task();
  }


  command error_t Init.init() {
    dcc.majik_a = DC_MAJIK;
    dcc.majik_b = DC_MAJIK;
    dcc.bufs_to_next_sync = SYNC_MAX_SECTORS;
    return SUCCESS;
  }


  /*
   * finish_sector
   *
   * sector is finished, zero dcc.remaining which will force getting
   * another buffer when we have more bytes to write out.
   *
   * Hand the current buffer off to the writer then reinitialize the
   * control cells to no buffer here.
   */
  void finish_sector() {
    nop();                              /* BRK */
    call SSW.buffer_full(dcc.handle);
    if (--dcc.bufs_to_next_sync == 0) {
      post collect_sync_task();
      dcc.bufs_to_next_sync = SYNC_MAX_SECTORS;
    }
    dcc.remaining = 0;
    dcc.handle    = NULL;
    dcc.cur_buf   = NULL;
    dcc.cur_ptr   = NULL;
  }


  void align_next() {
    unsigned int count;
    uint8_t *ptr;

    ptr = dcc.cur_ptr;
    count = (unsigned int) ptr & 0x03;
    if (dcc.remaining == 0 || !count)   /* nothing to align */
      return;
    if (dcc.remaining < 4) {
      finish_sector();
      return;
    }

    /*
     * we know there are at least 5 bytes left
     * chew bytes until aligned.  1, 2, or 3 bytes
     * actually 4 - count at this point.
     *
     * won't change checksum
     */
    switch (count) {
      case 1: *ptr++ = 0;
      case 2: *ptr++ = 0;
      case 3: *ptr++ = 0;
    }
    dcc.cur_ptr = ptr;
    dcc.remaining -= (4 - count);
  }


  /*
   * returns amount actually copied
   */
  static uint16_t copy_block_out(uint8_t *data, uint16_t dlen) {
    uint8_t  *ptr;
    uint16_t num_to_copy;
    unsigned int i;

    num_to_copy = ((dlen < dcc.remaining) ? dlen : dcc.remaining);
    ptr = dcc.cur_ptr;
    for (i = 0; i < num_to_copy; i++)
      *ptr++  = *data++;
    dcc.cur_ptr = ptr;
    dcc.remaining -= num_to_copy;
    return num_to_copy;
  }


  void copy_out(uint8_t *data, uint16_t dlen) {
    uint16_t num_copied;

    if (!data || !dlen)            /* nothing to do? */
      return;
    while (dlen > 0) {
      if (dcc.cur_buf == NULL) {
        /*
         * no space left, get another buffer
         * get_free_buf_handle either works or panics.
         */
        dcc.handle = call SSW.get_free_buf_handle();
        dcc.cur_ptr = dcc.cur_buf = call SSW.buf_handle_to_buf(dcc.handle);
        dcc.remaining = SD_BLOCKSIZE;
      }
      num_copied = copy_block_out(data, dlen);
      data += num_copied;
      dlen -= num_copied;
      if (dcc.remaining == 0)
        finish_sector();
    }
  }


  void finish_record(dt_header_t *header, uint16_t hlen,
                     uint8_t     *data,   uint16_t dlen) {
    uint16_t    chksum;
    uint32_t    i;

    dcc.cur_recnum++;
    header->recnum = dcc.cur_recnum;

    /*
     * upper layers are responsible for filling in any pad fields,
     * typically 0.  Pad fields are don't care but are part of the record
     * and are significant in the checksum.  We set to zero by convention.
     *
     * we need to compute the record chksum over all bytes of the header and
     * all bytes of the data area.  Additions to the chksum are done byte by
     * byte.  This has to be done before copying any of the data out and added
     * to the header (recsum).  Duh.  In other words, we have to finish updating
     * critical fields in the record header before coping it else where.
     *
     * Set recsum to 0.  Sum byte by byte all header and data bytes.  Then lay
     * in the computed 16 bit result as recsum.
     *
     * To verify, sum all bytes.  This result will include both recsum
     * bytes.  Remove the recsum bytes from result (as individual bytes)
     * and compare the result to recsum itself.  See checksum verify in
     * get_record in tagdump.py.  (tools/utils/tagdump/tagdump)
     */
    chksum = 0;
    header->recsum = 0;
    for (i = 0; i < hlen; i++)
      chksum += ((uint8_t *) header)[i];
    for (i = 0; data && i < dlen; i++)
      chksum += data[i];
    header->recsum = (uint16_t) chksum;
  }


  /*
   * All data fields are assumed to be little endian on both sides, tag and
   * host side.
   *
   * header is constrained to be 32 bit aligned (a(4)).  The size of header
   * must be less than DT_MAX_HEADER (+ 1) and data length must be less than
   * DT_MAX_DLEN (+ 1).  Data is immediately copied after the header (its
   * contiguous).
   *
   * hlen is the actual size of the header, dlen is the actual size of the
   * data.  hlen + dlen should match what is laid down in header->len.
   *
   * All dblk headers are assumed to start on a 32 bit boundary (aligned(4)).
   *
   * After writing a header/data combination (the whole typed_data block),
   * we align the next potential typed_data block onto a 32 bit boundary.
   * In other words we always keep typed_data blocks aligned in memory as
   * well as on the disk sector.
   *
   * dblk headers are constrained to fit completely into a data sector.  Data
   * immediately follows the dblk header as long as there is space.  Data
   * can flow into as many sectors as needed following the dblk header.
   */
  command void Collect.collect_nots(dt_header_t *header, uint16_t hlen,
                                    uint8_t     *data,   uint16_t dlen) {
    if (dcc.majik_a != DC_MAJIK || dcc.majik_b != DC_MAJIK)
      call Panic.panic(PANIC_SS, 1, dcc.majik_a, dcc.majik_b, 0, 0);
    if ((uint32_t) header & 0x3 || (uint32_t) dcc.cur_ptr & 0x03 ||
        dcc.remaining > SD_BLOCKSIZE)
      call Panic.panic(PANIC_SS, 2, (parg_t) header, (parg_t) dcc.cur_ptr, dcc.remaining, 0);
    if (header->len != (hlen + dlen) ||
        header->dtype > DT_MAX       ||
        hlen > DT_MAX_HEADER         ||
        (hlen + dlen) < 4)
      call Panic.panic(PANIC_SS, 3, hlen, dlen, header->len, header->dtype);

    if (hlen + dlen > DT_MAX_RLEN)
      call Panic.panic(PANIC_SS, 4, (parg_t) data, dlen, 0, 0);

    /* update recnum and calc the checksum */
    finish_record(header, hlen, data, dlen);
    nop();                              /* BRK */
    copy_out((void *)header, hlen);
    copy_out((void *)data,   dlen);
    align_next();
  }


  command void Collect.collect(dt_header_t *header, uint16_t hlen,
                               uint8_t     *data,   uint16_t dlen) {
    header->systime = call LocalTime.get();
    call Collect.collect_nots(header, hlen, data, dlen);
  }


  command void CollectEvent.logEvent(uint16_t ev, uint32_t arg0, uint32_t arg1,
                                                  uint32_t arg2, uint32_t arg3) {
    dt_event_t  e;
    dt_event_t *ep;

    ep = &e;
    ep->len = sizeof(e);
    ep->dtype = DT_EVENT;
    ep->ev   = ev;
    ep->arg0 = arg0;
    ep->arg1 = arg1;
    ep->arg2 = arg2;
    ep->arg3 = arg3;
    ep->pcode= 0;
    ep->w    = 0;
    ep->pad  = 0;
    call Collect.collect((void *)ep, sizeof(e), NULL, 0);
  }


  async event void SysReboot.shutdown_flush() {
    dt_sync_t  s;
    dt_sync_t *sp;

    nop();                              /* BRK */

    /*
     * System is going down.  We want SSW to flush any pending buffers.
     * This are the FULL buffers and we will let SSW handle them.
     *
     * However, Collect may have a pending (ALLOC'd) buffer.  The buffer is
     * ready to go as is.  But if we have room put one last sync record
     * down that records what we currently think current datetime is.
     * Yeah!
     */
    sp = &s;
    if (dcc.cur_buf) {
      /*
       * have a current buffer.  If we have space then add
       * a SYNC record, which will include a time corellator.
       */
      if (dcc.remaining >= sizeof(dt_sync_t)) {
        sp->len        = sizeof(dt_sync_t);
        sp->dtype      = DT_SYNC;
        sp->systime    = call LocalTime.get();
        sp->sync_majik = SYNC_MAJIK;
        sp->prev_sync  = dcc.last_sync_offset;
        sp->pad0       = sp->pad1       = 0;
        update_sync_offset();

        /* fill in datetime */

        /* add recnum and checksum the record */
        finish_record( (void *) sp, sizeof(dt_sync_t), NULL, 0);
        copy_block_out((void *) sp, sizeof(dt_sync_t));
      }
      dcc.remaining = 0;
    }
    call SSW.flush_all();
  }

  async event void Panic.hook() { }

}
