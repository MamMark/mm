/**
 * Copyright (c) 2018, Eric Decker
 * All rights reserved.
 *
 * @author Eric Decker
 */

interface PanicManager {
  /*
   * return start/end of the Panic file/area, abs sector blk_id
   */
  command uint32_t getPanicBase();
  command uint32_t getPanicLimit();

  /* return current index, also number of panics written */
  command uint32_t getPanicIndex();

  /* return max allowed index */
  command uint32_t getMaxPanicIndex();

  /* get panic block size, in sectors */
  command uint32_t getPanicSize();

  /* convert a panic index to absolute sector */
  command uint32_t panicIndex2Sector(uint32_t idx);

  /* request Panic to populate its control structures */
  command error_t populate();
  event   void    populateDone(error_t err);
}
