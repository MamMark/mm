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

#include <tagnet_panic.h>

module TagnetNameRootImplP {
  provides interface Tagnet;
  provides interface TagnetMessage   as  Sub[uint8_t id];
  uses interface     TagnetName      as  TName;
  uses interface     TagnetHeader    as  THdr;
  uses interface     TagnetPayload   as  TPload;
  uses interface     TagnetTLV       as  TTLV;
  uses interface     PlatformNodeId;
  uses interface     Boot;
  uses interface     Panic;
}
implementation {
  enum { SUB_COUNT = uniqueCount(UQ_TN_ROOT) };

  command bool Tagnet.process_message(message_t *msg) {
    tagnet_tlv_t    *this_tlv;
    uint8_t          i;

    if (!msg)
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE,
                       0, 0, 0, 0);       /* null trap */

    /* start at the beginning of the name
     * if null ptr returned, then this is ill-formed msg,
     * which will be ignored. Unrecognized message.
     */
    this_tlv = call TName.first_element(msg);
    // expect first TLV to be a Node Id type
    if ((!this_tlv) ||
        (call TTLV.get_tlv_type(this_tlv) != TN_TLV_NODE_ID))
      return FALSE;
    // ignore rsp msgs, since they are not from basestation
    if (call THdr.is_response(msg))
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

    if (limit < sizeof(global_node_id_buf))
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, 0, 0, 0, 0);

    for (i = 0; i < sizeof(global_node_id_buf); i++) {
      buf[i] = global_node_id_buf[i];
    }
    return i;
  }

  event void Boot.booted() {
    uint8_t     *node_id;
    unsigned int node_len, i;

    /* Before the network can start, we need to figure the
     * network identifier, or node_id, for this tag.  The
     * platform provides node id for the world-wide unique
     * TagNet network address. The node id is typically
     * derived from hardware based unique number, such as
     * the random number seed on the MSP432 or an Ethernet
     * MAC address ROM.
     *
     * TOS_NODE_ID is set to the first two bytes of the
     * node id because TinyOS uses it for the random number
     * generator.
     * zzz This should probably be done differently.
    */
    global_node_id_buf[0] = TN_TLV_NODE_ID;
    node_id    = call PlatformNodeId.node_id(&node_len);

    global_node_id_buf[1] = node_len;
    for (i = 0; i < node_len; i ++)
      global_node_id_buf[2+i] = node_id[i];

    TOS_NODE_ID = (uint16_t) *node_id;
  }


  default event bool Sub.evaluate[uint8_t id](message_t* msg)      { return TRUE; }
  default event void Sub.add_name_tlv[uint8_t id](message_t *msg)  { }
  default event void Sub.add_value_tlv[uint8_t id](message_t *msg) { }
  default event void Sub.add_help_tlv[uint8_t id](message_t *msg)  { }

  async event void Panic.hook(){ }
}
