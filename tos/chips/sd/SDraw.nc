/*
 * Copyright (c) 2010, Eric B. Decker, Carl W. Davis
 * All rights reserved.
 *
 * @author Eric B. Decker
 * @author Carl W. Davis
 */

interface SDraw {
  /**
   * SD raw, back door to SD card.
   * @return 
   *   <li>SUCCESS if the request was accepted, 
   *   <li>EINVAL  if the parameters are invalid
   *   <li>EBUSY if a request is alwritey being processed.
   *
   * if SUCCESS, it is guaranteed that future writeDone will be signalled.
   */
  command int send_cmd();
  command void get_ptrs(sd_cmd_t **cmd, sd_ctl_t **ctl);
}
