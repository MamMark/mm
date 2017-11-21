/**
 * Copyright (c) 2017, Eric Decker
 * All rights reserved.
 *
 * @author Eric Decker
 */

interface DblkManager {
  async command uint32_t get_nxt_blk();
  async command uint32_t adv_nxt_blk();
  async command uint32_t get_nxt_recnum();
}
