/*
 * Copyright (c) 2010, Eric B. Decker, Carl Davis
 * All rights reserved.
 *
 * @author Eric B. Decker
 * @author Carl Davis
 */

interface SDwrite {
  /**
   * SD write, split phase.
   *
   * @input	blk_id:  which block to read
   *		buf:	 where to get the data from, must SD_BUF_SIZE (514).
   *
   * @return 
   *   <li>SUCCESS if the request was accepted, 
   *   <li>EINVAL  if the parameters are invalid
   *   <li>EBUSY if a request is alwritey being processed.
   *
   * if SUCCESS, it is guaranteed that a future writeDone will be signalled.
   */
  command error_t write(uint32_t blk, uint8_t *buf);
  event   void    writeDone(uint32_t blk, uint8_t *buf, error_t error);
}
