/*
 * Copyright 2018: Eric B. Decker
 * All rights reserved.
 * Mam-Mark Project
 *
 * ResyncP.nc - data stream resynchronization.
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

module ResyncP {
  provides interface Resync[uint8_t cid];
  uses {
    interface Panic;
    interface ByteMapFile as DMF;
    interface Timer<TMilli> as ResyncTimer;
  }
}
implementation {
  // structure to manage state variables for reSync operation
  typedef struct {
    uint32_t cur_offset;    /* last place visited */
    uint32_t term_offset;   /* offset to halt search */
    uint32_t found_offset;  /* offset of found sync record, 0 if none */
    bool     in_progress;   /* search already in progress, try later */
    error_t  err;           /* error encountered during search */
    uint8_t  cid;           /* client id, current user */
  } scb_t;

  /* Sync Search Control Block (scb) */
  scb_t scb = {0, 0, -EINVAL, FALSE, SUCCESS, 0};

  /*
   * Dblk Record Resync
   *
   * The following provides Collect's resync functionality.  The primary
   * purpose of resync is to find the proper record alignment in the dblk
   * file.  This is sometimes lost or corrupted due to system failures. Other
   * times we just want to jump to an arbitrary position in the file and find
   * the record boundary. The sync record is used as the marker for this
   * alignment since it is laid down in the dblk file on a periodic basis and
   * has a well known format for correctly matching.
   *
   * resyncStart   command to initiate a search for a sync
   *               record starting at the specified offset
   *               in the dblk file. The terminal offset
   *               sets how far to search. If -1 then
   *               search to end of file.
   *
   *               SUCCESS: found result, new offset
   *                        returned
   *               EODATA:  not found within range, (beyond end
   *                        of file or terminal range).
   *               EBUSY:   disk io is in progress, result
   *                        will be signalled when done
   *
   * resyncDone    event to signal completion of search.
   *               returns offset
   *
   * Assumptions
   * - sync records are word aligned
   * - sync records are fixed length
   * - sync records can span across sector boundaries
   * - sync record structure definition is fixed (any
   *   future changes will affect this code)
   * - majik field is last field in sync record structure
   *
   * Algorithm
   * - if already searching, return EBUSY
   * - start a deadman timer
   * - initialize state variables
   * - repeat until sync record found or unrecoverable error:
   *   - call dmf.mapAll() with candidate offset and size of
   *     sync record. It returns success if all data is
   *     available or EBUSY if it needs to retrieve more data.
   *     It signal dmf.data_avail when is data and can now be
   *     accessed
   *   - check buffer to see if sync record is present, look
   *     for majik field, type, length, recsum
   *   - if valid sync record, then signal Collect.resyncDone
   *     and record file offset
   *   - otherwise, increment the offset by 4 bytes and try
   *     again
   * - terminate search and return EODATA when terminal
   *   offset has been exceeded or end of file is detected
   * - return SUCCESS and offset where sync record is located
   *   if sync record is detected
   *
   */

  bool sync_valid(dt_sync_t *sync) {
    uint16_t chksum;
    uint16_t i;
    uint8_t *ptr;

    if (sync->sync_majik != SYNC_MAJIK)
      return FALSE;
    if ((sync->dtype != DT_SYNC) &&
        (sync->dtype != DT_SYNC_FLUSH) &&
        (sync->dtype != DT_SYNC_REBOOT))
      return FALSE;
    if (sync->len != sizeof(dt_sync_t))
      return FALSE;
    ptr = (uint8_t *) sync;
    for (chksum = 0, i = 0; i < sync->len; i++)
      chksum += ptr[i];
    chksum -= (sync->recsum & 0xff00) >> 8;
    chksum -= (sync->recsum & 0x00ff);
    if (chksum != sync->recsum)
      return FALSE;
    return TRUE;
  }


  /*
   * core routine for finding sync records
   */
  uint32_t sync_search() {
    dt_sync_t    *sync;
    uint32_t      dlen = sizeof(dt_sync_t);

    scb.err = EODATA;
    while(scb.cur_offset < scb.term_offset) {
      scb.err = call DMF.mapAll(0, (uint8_t **) &sync, scb.cur_offset, &dlen);
      if(scb.err != SUCCESS)
        return 0; /* in case of EBUSY, sync_search is called again */
      if (dlen != sizeof(dt_sync_t) || !sync)
        call Panic.panic(PANIC_SS, 5, dlen, (parg_t) sync, 0,0);
      if (sync_valid(sync))
        return scb.cur_offset;
      scb.cur_offset += sizeof(uint32_t);
    }
    return 0;
  }

  /*
   * start the resync operation.
   */
  command error_t Resync.start[uint8_t cid](uint32_t *p_offset,
                                            uint32_t term_offset) {
    if (!p_offset)
      call Panic.panic(PANIC_SS, 6, 0,0,0,0);

    if (scb.in_progress) return EBUSY;

    scb.cid = cid;
    scb.in_progress  = TRUE;
    scb.found_offset = 0;
    scb.cur_offset = *p_offset & ~3;        // quad aligned.
    scb.term_offset = term_offset;
    call ResyncTimer.startOneShot(5000);    // five second deadman timer

    // look for sync record
    scb.found_offset = sync_search();

    if (scb.err == SUCCESS) {
      // found sync, set p_offset to new value
      *p_offset = scb.found_offset;
      call ResyncTimer.stop();
      scb.in_progress = FALSE;
    } else if (scb.err != EBUSY) {
      // detected unrecoverable error, terminate search
      *p_offset = -scb.err; // denote error
      call ResyncTimer.stop();
      scb.in_progress = FALSE;
    } // else busy reading next sector, try again later
    return scb.err;
  }


  /* handle signal when new data is available to continue search */
  event void DMF.data_avail(error_t err) {
    if (!scb.in_progress)       /* ignore if not ours */
      return;
    if ((scb.found_offset = sync_search()) || (scb.err != EBUSY)) {
      call ResyncTimer.stop();
      scb.in_progress = FALSE;
      signal Resync.done[scb.cid](scb.err, scb.found_offset);
    }
  }


  default event void Resync.done[uint8_t cid](error_t err, uint32_t offset) {
    call Panic.panic(PANIC_SS, 7, cid, 0, 0, 0);
  }


  command uint32_t Resync.offset[uint8_t cid]() {
    return (scb.in_progress ? 0 : scb.found_offset);
  }


  event void ResyncTimer.fired() {
    // deadman timer expired
    call Panic.panic(PANIC_SS, 8, 0, 0, 0, 0);
  }

  async event void Panic.hook() { }
}
