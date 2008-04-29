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
   * Flush a Stream handle.  This will cause the stream subsystem to write
   * the accumulated underlying buffer to the mass storage device.  The handle
   * is then returned to the free pool.
   *
   * If SUCCESS is returned, the StreamStorage subsystem has accepted responsibility
   * for the buffer and will write it to mass storage.  The the caller assumes this.
   *
   * @param handle address of a ss_handle (stream storage handle).
   * @return 
   *   <li>SUCCESS if the request was accepted, 
   *   <li>EINVAL if the parameters are invalid
   *   <li>EBUSY if a request is already being processed.
   */
  command error_t flush_handle(ss_handle_t *handle);

  /**
   * Convert a stream handle to its underlying buffer.
   *
   * @param handle address of a ss_handle (stream storage handle).
   * @return 
   *   <li>NULL   if bad handle or buffer not allocated.
   *   <li>buffer if good handle.
   */
  command uint8_t *handle_to_buf(ss_handle_t *handle);

  /**
   * request a new buffer from the Stream Storage system.
   *
   * @return 
   *   <li>NULL   if no buffer available.
   *   <li>handle if buffer available.  Buffer marked allocated.
   */
  command ss_handle_t* get_free_handle();

  /**
   * signalled when an underlying buffer is ready to be flushed.
   *
   * @param handle address of the ss_handle ready to be flushed.
   */  
  event void buffer_ready(ss_handle_t *handle);
}
