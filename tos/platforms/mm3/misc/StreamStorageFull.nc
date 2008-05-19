/**
 * Copyright (c) 2008, Eric Decker
 * All rights reserved.
 */

/**
 * @author Eric Decker
 */

interface StreamStorageFull {
  /**
   * The event "dblk_stream_full" is signaled when the assigned area
   * for data block storage is full.  Typically this will cause the
   * sensing system to shut down and put the tag into a low power
   * try to connect to the world mode.
   */  
  event void dblk_stream_full();

}
