/**
 * @Copyright (c) 2017-2018 Daniel J. Maltbie
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
  uses interface     Boot;
  uses interface     Panic;
}
implementation {
  enum { SUB_COUNT = uniqueCount(UQ_TN_ROOT) };

  command bool Tagnet.process_message(message_t *msg) {
    tagnet_tlv_t    *this_tlv;
    uint8_t          i;

    if (!msg)
      call Panic.panic(PANIC_TAGNET, 189, 0, 0, 0, 0);       /* null trap */

    // start at the beginning of the name
    this_tlv = call TName.first_element(msg);
    // expect first TLV to be a Node Id type
    if (call TTLV.get_tlv_type(this_tlv) != TN_TLV_NODE_ID)
      return FALSE;
    // Node Id in message must match one of
    // - my node's nid
    // - the broadcast nid
    if (!call TTLV.eq_tlv(this_tlv,  TN_MY_NID_TLV)
        && !call TTLV.eq_tlv(this_tlv,
                             (tagnet_tlv_t *)TN_BCAST_NID_TLV))
      return FALSE;

    for (i = 0; i < TN_TRACE_PARSE_ARRAY_SIZE; i++)
      tn_trace_array[i].id = TN_ROOT_ID;
    tn_trace_index = 1;
    nop();                               /* BRK */
    call TName.next_element(msg);
    // evaluate all subordinates for a name match
    for (i = 0; i<SUB_COUNT; i++) {
      nop();
      // if find a name match, then
      //   if rsp set, then send response msg
      if (signal Sub.evaluate[i](msg)) {
        if (call THdr.is_response(msg)) {
          return TRUE;             // match, response
        }
        return FALSE;              // match, no response
      }
    }
    return FALSE;                  // nothing matches
  }

  command uint8_t Sub.get_full_name[uint8_t id](uint8_t *buf, uint8_t limit) {
    uint32_t i;

    if (limit < sizeof(nid_buf))
      call Panic.panic(PANIC_TAGNET, 95, 0,0,0,0);

    for (i = 0; i < sizeof(nid_buf); i++) {
      buf[i] = nid_buf[i];
    }
    return i;
  }

  default event bool Sub.evaluate[uint8_t id](message_t* msg)      { return TRUE; }
  default event void Sub.add_name_tlv[uint8_t id](message_t *msg)  { }
  default event void Sub.add_value_tlv[uint8_t id](message_t *msg) { }
  default event void Sub.add_help_tlv[uint8_t id](message_t *msg)  { }

  event void Boot.booted() {
    uint32_t   i;
  /*
   * Initialize the Node Id using a portion of the MSP432 Random
   * number seed found in Device Descriptor TLVs (not the same
   * thing as Tagnet TLVs)
   *
   * 0x0020_1000 to 0x0020_1FFF	Device Descriptor (TLV)
   * 0000000Dh                       TAG_RANDNUM Random Number Tag
   *
   * Node_Id = (6 bytes starting at 0x201120)
   *
   * > x/6w 0x201118
   * 0x201118:	0x0000000d	0x00000004
   * 0x201120:	0xe5c88b65ff0c      0x5c20
   * 0x201128:	0xb321b7e6	0x8bb186c4
   */
    uint8_t *rand_seed = (uint8_t *)0x201120;

    nid_buf[0] = TN_TLV_NODE_ID;
    nid_buf[1] = 6;
    for (i = 0; i < 6; i ++)
      nid_buf[2+i] = rand_seed[i];
  }

  async event void Panic.hook(){ }
}
