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
   * @return 
   *   <li>SUCCESS if the request was accepted, 
   *   <li>EINVAL  if the parameters are invalid
   *   <li>EBUSY if a request is already being processed.
   *
   * if SUCCESS, it is guaranteed that future readDone will be signalled.
   */
  command error_t read(uint32_t blk, void *buf);
//  event   void    readDone(uint32_t blk, void *buf, error_t error);
}
