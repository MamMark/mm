/*
 * Copyright (c) 2010, Eric B. Decker, Carl Davis
 * All rights reserved.
 *
 * @author Eric B. Decker
 * @author Carl Davis
 */

interface SDreset {
  /**
   * SD reset, split phase.
   * @return 
   *   <li>SUCCESS if the request was accepted, 
   *   <li>EBUSY   if a request is already being processed.
   *   <li>FAIL
   *
   * if SUCCESS, it is guaranteed that a future resetDone will be signalled.
   */
  async command error_t reset();
  async event   void    resetDone(error_t error);
}
