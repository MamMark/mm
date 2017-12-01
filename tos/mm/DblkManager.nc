/**
 * Copyright (c) 2017, Eric Decker, Dan Maltbie
 * All rights reserved.
 *
 * @author Eric Decker
 * @author Dan Maltbie
 */

interface DblkManager {
  /* return start of the DBLK file, abs sector blk_id */
  async command uint32_t get_dblk_low();

  /* return the next abs blk_id that will be written next */
  async command uint32_t get_dblk_nxt();

  /* advance dblk_nxt and return the new value */
  async command uint32_t adv_dblk_nxt();

  /* advance cur_recnum and return the new value */
  async command uint32_t adv_cur_recnum();

  /* return the current record number (last record number assigned */
  async command uint32_t get_cur_recnum();
}
