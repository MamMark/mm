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

module TagnetNameRootImplP {
  provides interface Tagnet;
  provides interface TagnetMessage   as  Sub[uint8_t id];
  uses interface     TagnetName      as  TName;
  uses interface     TagnetHeader    as  THdr;
  uses interface     TagnetPayload   as  TPload;
  uses interface     TagnetTLV       as  TTLV;
}
implementation {
  enum { SUB_COUNT = uniqueCount(UQ_TN_ROOT) };

  command bool Tagnet.process_message(message_t *msg) {
    uint8_t          i;

    for (i = 0; i < TN_TRACE_PARSE_ARRAY_SIZE; i++) tn_trace_array[i].id = TN_ROOT_ID;
    tn_trace_index = 1;

    for (i = 0; i<SUB_COUNT; i++) {
      call TName.first_element(msg);     // start at the beginning of the name
      nop();
      if (signal Sub.evaluate[i](msg)) {
        if (call THdr.is_response(msg)) {
          return TRUE;                   // got a match and response to send
        }
        return FALSE;                    // matched but response not set
      }
    }
    return FALSE;                        // no match, no response
  }

  command uint8_t Sub.get_full_name[uint8_t id](uint8_t *buf, uint8_t len) {
    return len;
  }

  default event bool Sub.evaluate[uint8_t id](message_t* msg) {
    return TRUE;
  }
  default event void Sub.add_name_tlv[uint8_t id](message_t *msg) {
  }
  default event void Sub.add_value_tlv[uint8_t id](message_t *msg) {
  }
  default event void Sub.add_help_tlv[uint8_t id](message_t *msg) {
  }
}
