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

  /*
   * return current file relative offset of dblk_nxt (from dblk_low)
   * this is the file offset of the next block to be written.
   */
  async command uint32_t dblk_nxt_offset();

  /* advance dblk_nxt and return the new value */
  async command uint32_t adv_dblk_nxt();
}
