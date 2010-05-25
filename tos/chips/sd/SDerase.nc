/*
 * Copyright (c) 2010, Eric B. Decker, Carl Davis
 * All rights reserved.
 *
 * @author Eric B. Decker
 * @author Carl Davis
 */

interface SDerase {
  /**
   * SD erase, split phase.
   * @return 
   *   <li>SUCCESS if the request was accepted, 
   *   <li>EINVAL  if the parameters are invalid
   *   <li>EBUSY   if a request is already being processed.
   *
   * if SUCCESS, it is guaranteed that future eraseDone will be signalled.
   */
  command error_t erase(uint32_t blk_start, uint32_t blk_end);
  event   void    eraseDone(uint32_t blk_start, uint32_t blk_end, error_t error);
}
