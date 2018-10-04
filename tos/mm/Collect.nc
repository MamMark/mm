/*
 * Copyright (c) 2008, 2017-2018 Eric B. Decker
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

#include <typed_data.h>

interface Collect {
  command void collect(dt_header_t *header, uint16_t hlen,
                       uint8_t     *data,   uint16_t dlen);

  /* collect no timestamp.  Timestamp is filled by caller */
  command void collect_nots(dt_header_t *header, uint16_t hlen,
                            uint8_t     *data,   uint16_t dlen);

  async command uint32_t buf_offset();

  /* signal on Boot that Collect is happy and up */
  event void collectBooted();

  /**
   * resyncStart: request a Dblk resync
   *
   * Starting at the request offset, find the first SYNC record
   * if possible.
   *
   * @param uint32_t *p_offset   pointer to the offset.
   * @param uint32_t term_offset limiting offset.  (inclusive or exclusive?)
   *
   * @return error_t    SUCCESS if a SYNC was found and is cached.
   *                    EBUSY   SYNC not found yet, accessing Dblk subsystem.
   * @param uint32_t *p_offset updated with found offset (iff SUCCESS).
   *
   * if EBUSY is returned, a resyncDone signal will be generated at the
   * completion of the algorithm.
   *
   * non-SUCCESS and non-EBUSY indicate a non-recoverable error.
   */
  command error_t resyncStart(uint32_t *p_offset, uint32_t term_offset);

  /**
   * resyncDone: signal completion of resync process
   *
   * @param error_t err result
   *                    SUCCESS, offset contains the offset of the cached
   *                             SYNC record.
   *                    other, something went wrong.
   *
   * @param uint32_t offset, offset of the cached SYNC record (if found).
   *
   * SUCCESS indicates the resync finished.  Unexpected errors will Panic.
   * see code for returns that matter.
   */
  event void resyncDone(error_t err, uint32_t offset);
}
