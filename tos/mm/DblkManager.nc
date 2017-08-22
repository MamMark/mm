/**
 * Copyright (c) 2017, Eric Decker
 * All rights reserved.
 *
 * @author Eric Decker
 */

interface DblkManager {
  command uint32_t get_nxt_blk();
  command uint32_t adv_nxt_blk();
}
