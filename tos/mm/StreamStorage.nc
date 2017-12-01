/**
 * Copyright (c) 2008, 2010, 2017 Eric Decker
 * All rights reserved.
 */

interface StreamStorage {
  /**
   * return absolute blk_id of the start of the DBLK file
   */
  command uint32_t get_dblk_low();

  /**
   * The event "dblk_stream_full" is signaled when the assigned area
   * for data block storage is full.  Typically this will cause the
   * sensing system to shut down and put the tag into a low power
   * try to connect to the world mode.
   */
  event void dblk_stream_full();

  /**
   * The event dblk_advanced tells folks that a new dblk sector has
   * been written out to the SD.
   *
   * The parameter is last dblk blk_id that was written.
   */
  event void dblk_advanced(uint32_t last);
}
