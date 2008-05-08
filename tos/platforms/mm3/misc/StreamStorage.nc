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
   * Flush a Stream bufhandle.  This will cause the stream subsystem to write
   * the accumulated underlying buffer to the mass storage device.  The bufhandle
   * is then returned to the free pool.
   *
   * If SUCCESS is returned, the StreamStorage subsystem has accepted responsibility
   * for the buffer and will write it to mass storage.  The the caller assumes this.
   *
   * @param bufhandle address of a ss_bufhandle (stream storage bufhandle).
   * @return 
   *   <li>SUCCESS if the request was accepted, 
   *   <li>EINVAL if the parameters are invalid
   *   <li>EBUSY if a request is already being processed.
   */
  command error_t flush_buf_handle(ss_buf_handle_t *buf_handle);

  /**
   * Convert a stream buf_handle to its underlying buffer.
   *
   * @param buf_handle address of a ss_buf_handle (stream storage buf_handle).
   * @return 
   *   <li>NULL   if bad buf_handle or buffer not allocated.
   *   <li>buffer if good buf_handle.
   */
  command uint8_t *buf_handle_to_buf(ss_buf_handle_t *buf_handle);

  /**
   * request a new buffer from the Stream Storage system.
   *
   * @return 
   *   <li>NULL   if no buffer available.
   *   <li>buf_handle if buffer available.  Buffer marked allocated.
   */
  command ss_buf_handle_t* get_free_buf_handle();

  /**
   * signalled when an underlying buffer is ready to be flushed.
   *
   * @param buf_handle address of the ss_buf_handle ready to be flushed.
   */  
  event void buffer_ready(ss_buf_handle_t *buf_handle);
}
