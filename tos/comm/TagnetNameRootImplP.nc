/**
 * @Copyright (c) 2017 Daniel J. Maltbie
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 * See COPYING in the top level directory of this source tree.
 *
 * @author Daniel J. Maltbie <dmaltbie@daloma.org>
 */

#include <platform_panic.h>

#ifndef PANIC_TAGNET
enum {
  __pcode_tagnet = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_TAGNET __pcode_tagnet
#endif

module TagnetNameRootImplP {
  provides interface Tagnet;
  provides interface TagnetMessage   as  Sub[uint8_t id];
  uses interface     TagnetName      as  TName;
  uses interface     TagnetHeader    as  THdr;
  uses interface     TagnetPayload   as  TPload;
  uses interface     TagnetTLV       as  TTLV;
  uses interface     Panic;
}
implementation {
  enum { SUB_COUNT = uniqueCount(UQ_TN_ROOT) };

  command bool Tagnet.process_message(message_t *msg) {
    uint8_t          i;

    if (!msg)
      call Panic.panic(PANIC_TAGNET, 189, 0, 0, 0, 0);       /* null trap */
    for (i = 0; i < TN_TRACE_PARSE_ARRAY_SIZE; i++) tn_trace_array[i].id = TN_ROOT_ID;
    tn_trace_index = 1;
    nop();                               /* BRK */
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

  default event bool Sub.evaluate[uint8_t id](message_t* msg)      { return TRUE; }
  default event void Sub.add_name_tlv[uint8_t id](message_t *msg)  { }
  default event void Sub.add_value_tlv[uint8_t id](message_t *msg) { }
  default event void Sub.add_help_tlv[uint8_t id](message_t *msg)  { }

  async event void Panic.hook(){ }
}
