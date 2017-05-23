/**
 * Copyright (c) 2017 Daniel J. Maltbie
 * All rights reserved.
 *
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
 *
 * @author Daniel J. Maltbie <dmaltbie@daloma.org>
 *
 */

/**
 * Interface used to access the Tagnet names instantiated in this Tagnet stack.
 * The names are represented in a directed acyclical graph that matches the
 * request message name and processes the request if one-and-only-one leaf
 * in the graph is reached. A leaf provides Tagnet TLV typed interfaces that
 * are wired into the application modules for accessing configuration and
 * status parameters. An optional return response may be generated as a
 * result (e.g., request GET) that is ready for transmission.
 *
 * The same message buffer holding the request is modified to become the
 * response message. This preserves the name in the message but allows reuse
 * of the payload for response parameters. The message header is updated to
 * set the response message flag and error code as well as modify the 
 * message length to reflect changes in the payload length. Name length
 * is not modified.
 *
 */

interface TagnetMessage {
  /**
   * Process the request and optionally generate a response
   *
   * @param   msg    pointer to message buffer containing Tagnet Request packet
   * @return         TRUE if response to send, response uses request msg buffer.
   *                 Error can be checked by calling TagnetHeader.get_error();
   *
   */
  event bool  evaluate(message_t* msg);

  /**
   * Get the full name for the named data object
   *
   * traverses the graph in reverse to get the full name of a named data
   * object from the leaf's perspective.
   *
   * @param    buf    pointer to a buffer to hold the full name TLV list
   * @param    len    count of bytes available in buf
   * @return          length of name in bytes (0 == name too long for buffer)
   *
   */
  command uint8_t get_full_name(uint8_t* buf, uint8_t limit);

  event void add_name_tlv(message_t* msg);
  event void add_value_tlv(message_t* msg);
  event void add_help_tlv(message_t* msg);
}
