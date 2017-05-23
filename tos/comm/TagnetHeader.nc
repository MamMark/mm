/**
 * Copyright (c) 2017 Daniel J. Maltbie
 * All rights reserved.
 *
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
 *
 * @author Daniel J. Maltbie <dmaltbie@daloma.org>
 *
 */

#include "message.h"
#include "Tagnet.h"

interface TagnetHeader {
  command uint8_t           bytes_avail(message_t* msg);  // unused bytes in the buffer
  command tagnet_error_t    get_error(message_t *msg);
  command uint8_t           get_header_len(message_t *msg);
  command uint8_t           get_hops(message_t *msg);
  command uint8_t           get_message_len(message_t* msg);      // entire message length
  command tagnet_msg_type_t get_message_type(message_t *msg);
  command uint8_t           get_name_len(message_t *msg);
  command bool              is_pload_type_raw(message_t *msg);
  command bool              is_pload_type_tlv(message_t *msg);
  command bool              is_request(message_t *msg);
  command bool              is_response(message_t *msg);
  command uint8_t           max_user_bytes(message_t* msg);   // maximum bytes in the buffer
  command void              reset_header(message_t* msg);
  command void              set_error(message_t *msg, tagnet_error_t err);
  command void              set_hops(message_t *msg, uint8_t count);
  command void              set_message_len(message_t* msg, uint8_t len);
  command void              set_message_type(message_t *msg, tagnet_msg_type_t m_type);
  command void              set_name_len(message_t* msg, uint8_t len);
  command void              set_pload_type_raw(message_t *msg);
  command void              set_pload_type_tlv(message_t *msg);
  command void              set_request(message_t *msg);
  command void              set_response(message_t *msg);
}
