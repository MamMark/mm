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

/**
 * This module provides functions for handling the Header field
 * in a Tagnet Message
 *<p>
 * Each Tagnet message begins with the Header field. The first
 * byte specifies the length of the message, and is shared with
 * the radio hardware. This is followed by two bytes for the
 * message control parameters, and finally a fourth byte for the
 * length of the name.
 *</p>
 *<dl>
 *  <dt>Response Flag [7:1]</dt> <dd>TRUE(1) if message is a response</dd>
 *  <dt>Version [4:3]</dt> <dd>Currently set to 1</dd>
 *  <dt>Payload Type [0:1]</dt> <dd>TRUE(1) if payload is a TLV list</dd>
 *  <dt>Message Type [5:3]</dt> <dd>tagnet_msg_type_t enum value defining
 *   action to perform</dd>
 *  <dt>Option [0</dt> <dd>For a request message, this is the hop count; for
 *   a response it is the tagnet_error_t enum error code</dd>
 *</dl>
 *<p>
 * Bit field notation identifies two values: (1) a bit field
 * starting from the right with first bit being zero and (2) the
 * number of bits in the field counting upwards). So [7:1] is
 * a one bit wide field in the highestmost bit position (0x80).
 *</p>
 *<p>
 * Details of the Tagnet Message Header can be found in Si446xRadio.h
 *</p>
 */

#include "message.h"
#include "Tagnet.h"
#include "Si446xRadio.h"
#include <tagnet_panic.h>

module TagnetHeaderP {
  provides interface TagnetHeader;
  uses     interface Panic;
}
implementation {

  si446x_packet_header_t *getHdr(message_t *msg) {
    return (si446x_packet_header_t *) (&msg->data[0] - sizeof(si446x_packet_header_t));
    // return &msg->header[offsetof(message_t, data) - sizeof(si446x_packet_header_t)];
  }

  command uint8_t   TagnetHeader.bytes_avail(message_t* msg) {
    return sizeof(msg->data);
  }

  command tagnet_error_t    TagnetHeader.get_error(message_t *msg) {
    return ((tagnet_error_t) ((getHdr(msg)->tn_h2 & TN_H2_OPTION_M) >> TN_H2_OPTION_B));
  }

  command uint8_t   TagnetHeader.get_header_len(message_t* msg) {
    return sizeof(si446x_packet_header_t);
  }

  command uint8_t  TagnetHeader.get_hops(message_t *msg) {
    return ((getHdr(msg)->tn_h2 & TN_H2_OPTION_M) >> TN_H2_OPTION_B);
  }

  command uint8_t   TagnetHeader.get_message_len(message_t* msg) {
    return getHdr(msg)->frame_length;
  }

  command tagnet_msg_type_t  TagnetHeader.get_message_type(message_t* msg) {
    return ((tagnet_msg_type_t) ((getHdr(msg)->tn_h2 & TN_H2_MTYPE_M) >> TN_H2_MTYPE_B));
  }

  command uint8_t   TagnetHeader.get_name_len(message_t* msg) {
    return getHdr(msg)->name_length;
  }

  command bool   TagnetHeader.is_pload_type_raw(message_t *msg) {
    return (getHdr(msg)->tn_h1 & TN_H1_PL_TYPE_M) == 0;  // raw = 0
  }

  command bool   TagnetHeader.is_pload_type_tlv(message_t *msg) {
    return (getHdr(msg)->tn_h1 & TN_H1_PL_TYPE_M);       // tlv = 1
  }

  command bool   TagnetHeader.is_request(message_t *msg) {
    return ((getHdr(msg)->tn_h1 & TN_H1_RSP_F_M) == 0);  // request = 0
  }

  command bool   TagnetHeader.is_response(message_t *msg) {
    return (getHdr(msg)->tn_h1 & TN_H1_RSP_F_M);         // response = 1
  }

  command uint8_t   TagnetHeader.max_user_bytes(message_t* msg) {
    return TOSH_DATA_LENGTH;
  }

  command void   TagnetHeader.reset_header(message_t *msg) {
    uint8_t *h;
    int      x;
    h = (uint8_t *) getHdr(msg);
    for (x = 0; x < sizeof(si446x_packet_header_t); x++) {
      h[x] = 0;
    }
  }

  command void   TagnetHeader.set_error(message_t *msg, tagnet_error_t err) {
    getHdr(msg)->tn_h2 = ((err << TN_H2_OPTION_B) & TN_H2_OPTION_M)
      | (getHdr(msg)->tn_h2 & ~TN_H2_OPTION_M);
  }

  command  void   TagnetHeader.set_hops(message_t *msg, uint8_t count) {
    getHdr(msg)->tn_h2 = ((count << TN_H2_OPTION_B) & TN_H2_OPTION_M)
      | (getHdr(msg)->tn_h2 & ~TN_H2_OPTION_M);
  }

  command void   TagnetHeader.set_message_len(message_t* msg, uint8_t len) {
    getHdr(msg)->frame_length = len;
  }

  command void TagnetHeader.set_message_type(message_t *msg, tagnet_msg_type_t m_type) {
    getHdr(msg)->tn_h2 = ((m_type << TN_H2_MTYPE_B) & TN_H2_MTYPE_M)
      | (getHdr(msg)->tn_h2 & ~TN_H2_MTYPE_M);
  }

  command void   TagnetHeader.set_pload_type_raw(message_t *msg) {
    getHdr(msg)->tn_h1 &= ~TN_H1_PL_TYPE_M;   // raw payload = 0

  }

  command void   TagnetHeader.set_pload_type_tlv(message_t *msg) {
    getHdr(msg)->tn_h1 |= TN_H1_PL_TYPE_M;   // tlv payload = 1

  }

  command void   TagnetHeader.set_name_len(message_t* msg, uint8_t len) {
    getHdr(msg)->name_length = len;
  }

  command void   TagnetHeader.set_request(message_t *msg) {
    getHdr(msg)->tn_h1 &= ~TN_H1_RSP_F_M;  // request = 0
  }

  command void   TagnetHeader.set_response(message_t *msg) {
    getHdr(msg)->tn_h1 |= TN_H1_RSP_F_M;   // response = 1
  }

  async event void Panic.hook() { }
}
