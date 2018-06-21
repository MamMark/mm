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
 * This module provides functions for handling the Name field in a
 * Tagnet Message
 *<p>
 * A Tagnet name consists of a list of Tagnet type-data-value (TLV)
 * structures that together form a unique name for a specific data
 * object in the Tagnet Stack. A name is found in every Tagnet Message.
 *</p>
 *<p>
 * The naming scheme provides a flexible, extensible, and expressive
 * means to refer to a wide variety of information available on the
 * the Tag device. A name is structured in a hierarchical manner to
 * address a specific variable, presenting a network accessible
 * variable. Each name refers to some local information item such
 * as reading from a sensor, device configuration and status, or
 * state of the system. See TagnetMessage.nc for more details on
 * message processing.
 *</p>
 *<p>
 * This module uses metadata maintained in the message buffer that
 * specifies indices (offsets) into the message that refer to
 * various tlv types found in the name. Each time next_element(),
 * is called, the TLV type is checked and some types get special
 * handling.
 *</p>
 *<p>
 * The message metadata includes:
 *</p>
 *<dl>
 *  <dt>'this'</dt> <dd>tlv index of current tlv (starts at first and moves to next)</dd>
 *  <dt>'node_id'</dt> <dd>index to node_id tlv found in name</dd>
 *  <dt>'seq_no'</dt> <dd>index to seq_no tlv found in name</dd>
 *  <dt>'gps_xyz'</dt> <dd>index to gps_xyz tlv found in name</dd>
 *  <dt>'utc_time'</dt> <dd>index to utc_time found in name</dd>
 *</dl>
 *<p>
 * Note that 'seq_no' is tracked by metadata, but is removed from the
 * parsing since it is ephemeral to the name. It's used by adapters like
 * the TagnetFileAdapter component for indexing into the object.
 *</p>
 *<p>
 * Also note that typically the same buffer in which the request message
 * was received is turned into the response message. This preserves the
 * name and allows the header and payload to be updated.
 *</p>
 */

#include <message.h>
#include <Tagnet.h>
#include <TagnetTLV.h>
#include <tagnet_panic.h>

module TagnetNameP {
  provides interface   TagnetName;
  uses     interface   TagnetHeader   as  THdr;
  uses     interface   TagnetTLV      as  TTLV;
  uses     interface   Panic;
}
implementation {

  tagnet_name_meta_t *getMeta(message_t *msg) {
    return &(((message_metadata_t *)&(msg->metadata))->tn_name_meta);
  }

  command uint8_t   TagnetName.add_element(message_t* msg, tagnet_tlv_t* t) {
    tagnet_tlv_t     *this;
    int               added;

    this = call TagnetName.this_element(msg);
    added = call TTLV.copy_tlv(t, this, call TagnetName.bytes_avail(msg));
    getMeta(msg)->this += added;
    call THdr.set_name_len(msg, getMeta(msg)->this);
    call THdr.set_message_len(msg, call THdr.get_message_len(msg) + added);
    return added;
  }

  command uint8_t   TagnetName.bytes_avail(message_t* msg) {
    return (sizeof(msg->data) - getMeta(msg)->this);
  }

  async command tagnet_tlv_t *TagnetName.first_element(message_t *msg) {
    memset(getMeta(msg), 0, sizeof(tagnet_name_meta_t));
    return call TagnetName.this_element(msg);
  }

  async command tagnet_tlv_t *TagnetName.this_element(message_t *msg) {
    return (tagnet_tlv_t *) &msg->data[getMeta(msg)->this];
  }

  command tagnet_tlv_t  *TagnetName.get_gps_xyz(message_t *msg) {
    if (!msg)
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, 0, 0, 0, 0);

    if (!getMeta(msg)->gps_xyz) return NULL;
    return (tagnet_tlv_t *) ( &msg->data[(getMeta(msg)->gps_xyz)] );
  }

  command uint8_t    TagnetName.get_len(message_t* msg) {
    if (!msg)
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, 0, 0, 0, 0);

    return call THdr.get_name_len(msg);
  }

  command tagnet_tlv_t   *TagnetName.get_node_id(message_t *msg) {
    if (!msg)
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, 0, 0, 0, 0);

    if (getMeta(msg)->node_id == 0) return NULL;
    return (tagnet_tlv_t *) ( &msg->data[(getMeta(msg)->node_id)] );
  }

  command tagnet_tlv_t     *TagnetName.get_offset(message_t *msg) {
    if (!msg)
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, 0, 0, 0, 0);

    if (getMeta(msg)->offset == 0) return NULL;
    return (tagnet_tlv_t *) ( &msg->data[(getMeta(msg)->offset)] );
  }

  command tagnet_tlv_t     *TagnetName.get_version(message_t *msg) {
    if (!msg)
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, 0, 0, 0, 0);

    if (getMeta(msg)->version == 0) return NULL;
    return (tagnet_tlv_t *) ( &msg->data[(getMeta(msg)->version)] );
  }

  command tagnet_tlv_t     *TagnetName.get_size(message_t *msg) {
    if (!msg)
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, 0, 0, 0, 0);

    if (getMeta(msg)->size == 0) return NULL;
    return (tagnet_tlv_t *) ( &msg->data[(getMeta(msg)->size)] );
  }

  command tagnet_tlv_t     *TagnetName.get_utc_time(message_t *msg) {
    if (!msg)
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, 0, 0, 0, 0);

    if (getMeta(msg)->utc_time == 0) return NULL;
    return (tagnet_tlv_t *) ( &msg->data[(getMeta(msg)->utc_time)] );
  }

  command tagnet_tlv_t   *TagnetName.next_element(message_t *msg) {
//  command __attribute__((optimize("O0"))) tagnet_tlv_t   *TagnetName.next_element(message_t *msg) {
    tagnet_tlv_t      *this_tlv;
    tagnet_tlv_t      *next_tlv;
    uint8_t           *name_start    =  (uint8_t *)&msg->data[0];
    uint8_t            name_length   =  call THdr.get_name_len(msg);

    nop();
    nop();
    if ((!msg) || (getMeta(msg)->this > call THdr.get_name_len(msg)))
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, 0, 0, 0, 0);
    do {
      nop();
      this_tlv = call TagnetName.this_element(msg);
      next_tlv = call TTLV.get_next_tlv(this_tlv, name_length);
      if ( (next_tlv == NULL)
            || ((void *)next_tlv < (void *)this_tlv)
            || ((void *)next_tlv >= (void *)&msg->data[name_length]) ) {
          return NULL;
      }

      getMeta(msg)->this = (int) next_tlv - (int) name_start; // advance 'this' index to 'next' in list
      switch (call TTLV.get_tlv_type(next_tlv)) {       // some tlvs get special handling

        case TN_TLV_OFFSET:   // byte offset, mark location
          call TagnetName.set_offset(msg);
          return next_tlv;

        case TN_TLV_SIZE:     // amount to get, mark location
          call TagnetName.set_size(msg);
          return next_tlv;

        case TN_TLV_VERSION:  // version, mark location
          call TagnetName.set_version(msg);
          return next_tlv;

        case TN_TLV_NODE_ID:  // node_id, mark location
          call TagnetName.set_node_id(msg);
          return next_tlv;

        case TN_TLV_GPS_XYZ:  // gps_xyz, mark location
          call TagnetName.set_gps_xyz(msg);
          return next_tlv;

        case TN_TLV_UTC_TIME: // utc_time, mark location
          call TagnetName.set_utc_time(msg);
          return next_tlv;

        case TN_TLV_NONE:
          return NULL;

        default:
          return next_tlv;
        }
    } while (getMeta(msg)->this < name_length);
    return NULL;
  }

  command void   TagnetName.reset_name(message_t* msg) {
    if (!msg)
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, 0, 0, 0, 0);

    getMeta(msg)->this = 0;
    call THdr.set_name_len(msg, 0);
  }

  command void    TagnetName.set_gps_xyz(message_t *msg) {
    if (!msg)
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, 0, 0, 0, 0);

    getMeta(msg)->gps_xyz = getMeta(msg)->this;
  }

  command void     TagnetName.set_node_id(message_t *msg) {
    if (!msg)
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, 0, 0, 0, 0);

    getMeta(msg)->node_id = getMeta(msg)->this;
  }

  command void    TagnetName.set_offset(message_t *msg) {
    if (!msg)
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, 0, 0, 0, 0);

    getMeta(msg)->offset = getMeta(msg)->this;
  }

  command void    TagnetName.set_size(message_t *msg) {
    if (!msg)
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, 0, 0, 0, 0);

    getMeta(msg)->size = getMeta(msg)->this;
  }

  command void    TagnetName.set_version(message_t *msg) {
    if (!msg)
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, 0, 0, 0, 0);

    getMeta(msg)->version = getMeta(msg)->this;
  }

  command void    TagnetName.set_utc_time(message_t *msg) {
    if (!msg)
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, 0, 0, 0, 0);

    getMeta(msg)->utc_time = getMeta(msg)->this;
  }

  command bool              TagnetName.is_last_element(message_t *msg) {
    tagnet_tlv_t       *this_tlv = call TagnetName.this_element(msg);
    uint16_t            name_consumed;

    if (!msg)
      call Panic.panic(PANIC_TAGNET, TAGNET_AUTOWHERE, 0, 0, 0, 0);

    name_consumed = getMeta(msg)->this + SIZEOF_TLV(this_tlv);
    if (name_consumed >= call THdr.get_name_len(msg))
      return TRUE;
    return FALSE;
  }

  async event void Panic.hook() { }
}
