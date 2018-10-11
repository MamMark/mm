/*
 * Copyright (c) 2018 Eric B. Decker
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

interface Resync {
  /**
   * start: request a Dblk resync
   *
   * Starting at the requested offset, find the first SYNC record
   * if possible.
   *
   * @param uint32_t *p_offset   pointer to the offset.
   * @param uint32_t term_offset limiting offset.  (inclusive or exclusive?)
   *
   * @return error_t    SUCCESS if a SYNC was found and is cached.
   *                    EBUSY   SYNC not found yet, accessing Dblk subsystem.
   * @param uint32_t *p_offset updated with found offset (iff SUCCESS).
   *
   * if EBUSY is returned, a Resync.done() signal will be generated at the
   * completion of the algorithm.
   *
   * non-SUCCESS/non-EBUSY indicate a non-recoverable error.
   */
  command error_t start(uint32_t *p_offset, uint32_t term_offset);

  /**
   * done: signal completion of resync process
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
  event void done(error_t err, uint32_t offset);

  /**
   * offset: return last rsync offset.
   *
   * @return uint32_t   last resync offset if any.  0 no resync
   *                    done or a resync is in progress.
   */
  command uint32_t offset();
}
