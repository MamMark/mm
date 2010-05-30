/*
 * Copyright (c) 2010, Eric B. Decker, Carl Davis
 * All rights reserved.
 *
 * @author Eric B. Decker
 * @author Carl Davis
 */

interface SDread {
  /**
   * SD read, split phase.
   *
   * @input	blk_id:  which block to read
   *		buf:	 where to put the data, must SD_BUF_SIZE (514).
   *
   * @return 
   *   <li>SUCCESS if the request was accepted, 
   *   <li>EINVAL  if the parameters are invalid
   *   <li>EBUSY if a request is already being processed.
   *
   * if SUCCESS, it is guaranteed that a future readDone will be signalled.
   */
  command error_t read(uint32_t blk_id, uint8_t *buf);
  event void  readDone(uint32_t blk_id, uint8_t *buf, error_t error);
}
