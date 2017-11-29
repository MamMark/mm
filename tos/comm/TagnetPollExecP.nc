/**
 * This module provides functions for adapting system execution
 * control variables.
 *
 *<p>
 * @author Daniel J. Maltbie <dmaltbie@daloma.org>
 *
 * @Copyright (c) 2017 Daniel J. Maltbie
 * All rights reserved.
 *</p>
 */
/* Redistribution and use in source and binary forms, with or without
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
#include <message.h>
#include <Tagnet.h>
#include <TagnetTLV.h>
#include <image_info.h>
#include <overwatch.h>

module TagnetPollExecP {
  provides interface TagnetAdapter<int32_t>    as PollCount;
  provides interface TagnetAdapter<message_t>  as PollEvent;
  uses     interface TagnetName                as  TName;
  uses     interface TagnetHeader              as  THdr;
  uses     interface TagnetPayload             as  TPload;
  uses     interface TagnetTLV                 as  TTLV;
  uses     interface ImageManagerData          as  IMD;
  uses     interface OverWatch                 as  OW;
}
implementation {
  int32_t poll_count = 0;

  command bool PollCount.get_value(int32_t *t, uint8_t *l) {
    nop();
    nop();
    *t = poll_count;
    *l = sizeof(int32_t);
    return TRUE;
  }

  command bool PollEvent.get_value(message_t *msg, uint8_t *l) {
    tagnet_tlv_t    *this_tlv;
    nop();
    nop();
    call THdr.set_response(msg); // zzz need to move inside name match
    poll_count++;
    switch (call THdr.get_message_type(msg)) {    // process packet type
      case TN_POLL:
        this_tlv = call TPload.first_element(msg);
        // zzz get request parameters from payload
        call TPload.reset_payload(msg);
        call THdr.set_error(msg, TE_PKT_OK);
        call TPload.add_integer(msg, poll_count);
        // zzz add name, position, mac address, sw version, etc
        return TRUE;
      default:
        break;
    }
    call THdr.set_error(msg, TE_PKT_NO_MATCH);
    return FALSE;                                  // no match, do nothing
  }
}
