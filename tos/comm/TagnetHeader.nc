/**
 * Accessor functions for manipulating the Tagnet Message Header fields.
 *<p>
 * The Tagnet header includes the message length, the name length, the
 * message type, request/response flag, hops/error field, and payload
 * type.
 *</p>
 *<p>
 * Message types include:
 *</p>
 *<dl>
 * <dt>POLL</dt> <dd>Master poll message, usually broadcasted and requires a time slotted response</dd>
 * <dt>BEACON</dt> <dd>All nodes listen for beacons to find adjacent nodes</dd>
 * <dt>GET</dt> <dd>Get current value of name element. If this is the terminal element in the name, then get its value. If it is an intermediate element, then get values for all sub-elements of this name element (like a directory listing)</dd>
 * <dt>PUT</dt> <dd>Set current value of the name element. Note that some objects cannot be modified and an error will be returned</dd>
 * <dt>HEAD</dt> <dd>Get metadata about the name element</dd>
 * <dt>HELP</dt> <dd>Get help information about the named element</dd>
 *</dl>
 *<p>
 * Note that the hops/error field is in the same location in the header.
 * The hops count is used in the request message while the error is
 * in the response message.
 *</p>
 * @author Daniel J. Maltbie <dmaltbie@daloma.org>
 *
 * @Copyright (c) 2017 Daniel J. Maltbie
 * All rights reserved.
 */
/*
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 *
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include "message.h"
#include "Tagnet.h"

interface TagnetHeader {
  /**
   * Number of bytes available in message, excluding message header. This is
   * the free buffer space to hold name and payload data.
   *
   * @param   msg           pointer to message buffer containing Tagnet message
   * @return  uint8_t       number of unused bytes in message buffer
   */
  command uint8_t   bytes_avail(message_t* msg);  // unused bytes in the buffer
  /**
   * Get error code stored in header
   *
   * @param   msg           pointer to message buffer containing Tagnet message
   * @return  tagnet_error_t Tagnet error code
   */
  command tagnet_error_t   get_error(message_t *msg);
  /**
   * Get the length of the message header (fixed at 4 bytes).
   *
   * @param   msg           pointer to message buffer containing Tagnet message
   * @return  uint8_t       length of header
   */
  command uint8_t   get_header_len(message_t *msg);
  /**
   * Get value of the number of hops field
   *
   * @param   msg           pointer to message buffer containing Tagnet message
   * @return  uint8_t       number of hops remaining
   */
  command uint8_t   get_hops(message_t *msg);
  /**
   * Get length of entire message buffer (includes header)
   *
   * @param   msg           pointer to message buffer containing Tagnet message
   * @return  uint8_t       length of entire message buffer
   */
  command uint8_t   get_message_len(message_t* msg);      // entire message length
  /**
   * Get message type
   *
   * @param   msg           pointer to message buffer containing Tagnet message
   * @return  tagnet_msg_type_t type of message
   */
  command tagnet_msg_type_t get_message_type(message_t *msg);
  /**
   * Get length of the name in the message buffer
   *
   * @param   msg           pointer to message buffer containing Tagnet message
   * @return  uint8_t       length of name in message buffer
   */
  command uint8_t   get_name_len(message_t *msg);
  /**
   * Check to see if payload type is raw bytes
   *
   * @param   msg           pointer to message buffer containing Tagnet message
   * @return  bool          TRUE if payload type is set to raw
   */
  command bool   is_pload_type_raw(message_t *msg);
  /**
   * Check to see if payload type is list of tlvs
   *
   * @param   msg           pointer to message buffer containing Tagnet message
   * @return  bool          TRUE if payload type is set to tlv list
   */
  command bool   is_pload_type_tlv(message_t *msg);
  /**
   * Check to see if message is a request message
   *
   * @param   msg           pointer to message buffer containing Tagnet message
   * @return  bool          TRUE if request message
   */
  command bool   is_request(message_t *msg);
  /**
   * Check to see if message is a response message
   *
   * @param   msg           pointer to message buffer containing Tagnet message
   * @return  bool          TRUE if response message
   */
  command bool   is_response(message_t *msg);
  /**
   * Maximum space in message for name + payload (TOSH_DATA_LENGTH)
   *
   * @param   msg           pointer to message buffer containing Tagnet message
   * @return  uint8_t       maximum space available for name + payload
   */
  command uint8_t   max_user_bytes(message_t* msg);
  /**
   * Reset header to initial state (zeros out all fields). Sets message_length
   * to size of header and message request TRUE
   *
   * @param   msg           pointer to message buffer containing Tagnet message
   */
  command void  reset_header(message_t* msg);
  /**
   * Set header message error (must be a request message)
   *
   * @param   msg           pointer to message buffer containing Tagnet message
   */
  command void   set_error(message_t *msg, tagnet_error_t err);
  /**
   * Set header hop count field (must be a response message).
   *
   * @param   msg           pointer to message buffer containing Tagnet message
   */
  command void   set_hops(message_t *msg, uint8_t count);
  /**
   * Set header message length to current length of header + name + payload
   *
   * @param   msg           pointer to message buffer containing Tagnet message
   */
  command void    set_message_len(message_t* msg, uint8_t len);
  /**
   * Set message type
   *
   * @param   msg           pointer to message buffer containing Tagnet message
   */
  command void    set_message_type(message_t *msg, tagnet_msg_type_t m_type);
  /**
   * Set head name length in header
   *
   * @param   msg           pointer to message buffer containing Tagnet message
   */
  command void   set_name_len(message_t* msg, uint8_t len);
  /**
   * Set header payload type field to raw bytes
   *
   * @param   msg           pointer to message buffer containing Tagnet message
   */
  command void    set_pload_type_raw(message_t *msg);
  /**
   * Set header payload type field to tlv list.
   *
   * @param   msg           pointer to message buffer containing Tagnet message
   */
  command void   set_pload_type_tlv(message_t *msg);
  /**
   * Set header to make message a request
   *
   * @param   msg           pointer to message buffer containing Tagnet message
   */
  command void   set_request(message_t *msg);
  /**
   * Set header to make message a response
   *
   * @param   msg           pointer to message buffer containing Tagnet message
   */
  command void   set_response(message_t *msg);
}
