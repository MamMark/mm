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

interface ByteMapFile {
  /**
   * A File/Object mapping implementation that provides cached access to
   * objects that live on a physical disk subsystem.
   *
   * This interface provides four commands and three events:
   *
   * commands:
   *    map():        requests a buffer pointer to a region of the file.
   *                  If the data needs to be brought in from disk, map()
   *                  will return EBUSY and data_avail() will be signalled
   *                  to indicate new data is available.
   *    mapAll():     same as map(), but requires that all data requested
   *                  be in the cache to be successful. Will return EBUSY
   *                  if additional data needs to be added to cache for
   *                  success and data_avail() will be signalled to
   *                  indicate all data is now available.
   *    filesize():   get the current filesize.
   *    commitsize(): get the current filesize that has been committed
   *        to disk.
   *
   * events:
   *    data_avail(): indicates data has been brought in from disk and is
   *                  available.  The originating request should be
   *                  initiated again.
   *    extended():   indicates that the object has been extended.
   *    committed():  indicates that object's data physically written to
   *                  disk has been extended.
   */

  /**
   * map() and mapAll()
   *
   * Request a portion of the referenced object be brought into memory.
   * The buffer returned is independent of any underlying file caching
   * mechanisms.  It remains valid until the next map() call.
   *
   * If the section requested is already cached, SUCCESS will be returned
   * and a pointer to that region and its length is immediately returned.
   * 'length' is potentially less than the original request, and indicates
   * how much data in the returned buffer is valid.
   *
   * For map(), if any cached data can be used, that is the data that is
   * returned. For mapAll(), all data must be in cache before any of it
   * is returned.
   *
   * If no cached data can be used, we will need to access the underlying
   * backing store.  map() will return EBUSY.  The needed portion will be
   * brought in and when complete the signal data_avail() will be used to
   * indicate that additional data is available.  The previous request must
   * be launched again to access the new data.
   *
   * If the map() call can not satisfy any portion of the request, ie. past
   * the EOF for example, EODATA will be returned.
   *
   * The context identifier is used to reference multiple instances within
   * the container we are accessing.  ie. which image in the ImageManager
   * space, or which Panic Block in the Panic Area.
   *
   * @param   'uint32_t   context'
   * @param   'uint8_t  **bufp'     pointer to buf pointer
   * @param   'uint32_t   offset'   file offset looking for
   * @param   'uint32_t  *lenp'     pointer to length requested/available
   *
   * @return  'error_t'             error code
   *          SUCCESS               some portion of the request is immediately
   *                                available.
   *          EBUSY                 no data immediately available.  map() is
   *                                obtaining the data and a data_avail()
   *                                signal will indicate availablity of the
   *                                data.
   *          EODATA                The request completely likes outside the
   *                                current bounds of the contents.
   */
  command error_t map(uint32_t context, uint8_t **bufp,
                      uint32_t offset, uint32_t *lenp);

  command error_t mapAll(uint32_t context, uint8_t **bufp,
                         uint32_t offset, uint32_t *lenp);

  /**
   * signal when the requested contents has been mapped into memory.
   *
   * @param   'error_t    err'      0 - all good, otherwise error
   */
  event void data_avail(error_t err);

  /**
   * return size of file in bytes
   *
   * @param   'uint32_t context'
   * @return  'uint32_t'      file size in bytes
   */
  command uint32_t filesize(uint32_t context);

  /**
   * commitsize: number of bytes physically written to disk.
   *
   * the underlying implementation may provide caching of the file.
   * filesize() returns the current file size, while commitsize() returns
   * the number of bytes that have been physically written to disk.
   *
   * @param   'uint32_t context'
   * @return  'uint32_t'      file size committed to disk.
   */
  command uint32_t commitsize(uint32_t context);

  /**
   * signal when the file grows.
   *
   * @param   'uint32_t context'
   * @param   'uint32_t offset'  new eof offset
   */
  event   void     extended(uint32_t context, uint32_t offset);

  /**
   * signal when data has been written.
   *
   * @param   'uint32_t context'
   * @param   'uint32_t offset'  new commited offset
   */
  event   void     committed(uint32_t context, uint32_t offset);
}
