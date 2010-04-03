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
   * @return 
   *   <li>SUCCESS if the request was accepted, 
   *   <li>EINVAL  if the parameters are invalid
   *   <li>EBUSY if a request is alwritey being processed.
   *
   * if SUCCESS, it is guaranteed that future writeDone will be signalled.
   */
  command error_t write(uint32_t blk, void *buf);
//  event   void    writeDone(uint32_t blk, void *buf, error_t error);
}
