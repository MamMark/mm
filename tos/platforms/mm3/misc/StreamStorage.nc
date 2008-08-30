/**
 * Copyright (c) 2008, Eric Decker
 * All rights reserved.
 */

/**
 * @author Eric Decker
 */

#include "stream_storage.h"

interface StreamStorage {
  /*
   * StreamStorage provides an interface to sector orientated 512 byte
   * stream storage devices.  Data is accessed as blocks of 512 bytes.
   * A stream of 512 byte blocks is written to the stream device.
   */

  /**
   * Convert a stream buf_handle to its underlying buffer.
   *
   * @param buf_handle address of a ss_buf_handle (stream storage buf_handle).
   * @return 
   *   <li>NULL   if bad buf_handle or buffer not allocated.
   *   <li>buffer if good buf_handle.
   */
  command uint8_t *buf_handle_to_buf(ssw_buf_handle_t *buf_handle);

  /**
   * request a new buffer from the Stream Storage system.
   *
   * @return 
   *   <li>NULL   if no buffer available.
   *   <li>buf_handle if buffer available.  Buffer marked allocated.
   */
  command ssw_buf_handle_t* get_free_buf_handle();

  /**
   * call when the buffer objectified by buf_handle has been
   * filled and should be flushed.  The handle is then returned to the
   * free pool.  Do not use after calling buffer_full.
   *
   * @param buf_handle address of the ss_buf_handle ready to be flushed.
   */  
  command void buffer_full(ssw_buf_handle_t *buf_handle);

  /**
   * check a buffer (assumed to be 512 bytes) according to whatever
   * streamstorage does to look for an empty buffer.
   *
   * @param buf buffer to check for empty.
   *
   * @return
   *    <li> FALSE	buffer not empty
   *    <li> TRUE	buffer empty
   */
  command bool buffer_empty(uint8_t *buf);
}
