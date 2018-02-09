/*
 * Copyright (c) 2017 Daniel J. Maltbie
 * Copyright (c) 2018 Daniel J. Maltbie, Eric B. Decker
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
 * Contact: Daniel J.Maltbie <dmaltbie@daloma.org>
 *          Eric B. Decker <cire831@gmail.com>
 */

interface ByteMapFileNew {
  /**
   * The underlying file mapping implementation provides cached access to a
   * file that lives on a physical disk subsystem.
   *
   * This interface provides 3 commands and one event:
   *
   *    map(): request a pointer to a region of the file.  mapped() will be
   *        signaled if the data isn't immediately availablee.
   *    filesize(): get the current filesize.
   *    commited(): get the current filesize that has been committed
   *        to disk.
   */

  /**
   * Request that a region of the file be brought into memory.  The buffer
   * returned is independent of the underlying file mechanisms.  It remains
   * valid until the next map() call.
   *
   * If the section requested is already cached, a pointer to that region
   * and its length is immediately returned (potentially less than the
   * original request).  Otherwise, an EBUSY return will be given and some
   * or all of the requested region will be brought in.  When complete, a
   * mapped() signal will be used to indicate data is now available.
   *
   * @param   'uint8_t  **buf'      pointer to buf pointer
   * @param   'uint32_t   offset'   file offset looking for
   * @param   'uint32_t  *len'      pointer to length requested/available
   *
   * @return  'error_t'             error code
   */
  command error_t map(uint8_t **buf, uint32_t offset, uint32_t *len);

  /**
   * signal when a the file has been extended.
   *
   * @param   'uint8_t   *buf'      where the data lives
   * @param   'uint32_t   offset'   requested file offset mapped.
   * @param   'uint32_t  *len'      pointer to length available/used
   */
  event void mapped(uint8_t *buf, uint32_t offset, uint32_t len);

  /**
   * return size of file in bytes
   *
   * @return  'uint32_t'       file size in bytes
   */
  command uint32_t filesize();

  /**
   * return commited size of file in bytes.
   * the underlying implementation may provide caching
   * of the file.  filesize() returns the current file
   * size, while committed() returns the number of bytes
   * that have been physically written to disk.
   *
   * @return  'uint32_t'       file size written to disk.
   */
  command uint32_t committed();
}
