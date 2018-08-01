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

  const uint8_t crcTable[] = {0x00, 0x07, 0x0e, 0x09, 0x1c, 0x1b, 0x12, 0x15, 0x38,
                              0x3f, 0x36, 0x31, 0x24, 0x23, 0x2a, 0x2d, 0x70, 0x77,
                              0x7e, 0x79, 0x6c, 0x6b, 0x62, 0x65, 0x48, 0x4f, 0x46,
                              0x41, 0x54, 0x53, 0x5a, 0x5d, 0xe0, 0xe7, 0xee, 0xe9,
                              0xfc, 0xfb, 0xf2, 0xf5, 0xd8, 0xdf, 0xd6, 0xd1, 0xc4,
                              0xc3, 0xca, 0xcd, 0x90, 0x97, 0x9e, 0x99, 0x8c, 0x8b,
                              0x82, 0x85, 0xa8, 0xaf, 0xa6, 0xa1, 0xb4, 0xb3, 0xba,
                              0xbd, 0xc7, 0xc0, 0xc9, 0xce, 0xdb, 0xdc, 0xd5, 0xd2,
                              0xff, 0xf8, 0xf1, 0xf6, 0xe3, 0xe4, 0xed, 0xea, 0xb7,
                              0xb0, 0xb9, 0xbe, 0xab, 0xac, 0xa5, 0xa2, 0x8f, 0x88,
                              0x81, 0x86, 0x93, 0x94, 0x9d, 0x9a, 0x27, 0x20, 0x29,
                              0x2e, 0x3b, 0x3c, 0x35, 0x32, 0x1f, 0x18, 0x11, 0x16,
                              0x03, 0x04, 0x0d, 0x0a, 0x57, 0x50, 0x59, 0x5e, 0x4b,
                              0x4c, 0x45, 0x42, 0x6f, 0x68, 0x61, 0x66, 0x73, 0x74,
                              0x7d, 0x7a, 0x89, 0x8e, 0x87, 0x80, 0x95, 0x92, 0x9b,
                              0x9c, 0xb1, 0xb6, 0xbf, 0xb8, 0xad, 0xaa, 0xa3, 0xa4,
                              0xf9, 0xfe, 0xf7, 0xf0, 0xe5, 0xe2, 0xeb, 0xec, 0xc1,
                              0xc6, 0xcf, 0xc8, 0xdd, 0xda, 0xd3, 0xd4, 0x69, 0x6e,
                              0x67, 0x60, 0x75, 0x72, 0x7b, 0x7c, 0x51, 0x56, 0x5f,
                              0x58, 0x4d, 0x4a, 0x43, 0x44, 0x19, 0x1e, 0x17, 0x10,
                              0x05, 0x02, 0x0b, 0x0c, 0x21, 0x26, 0x2f, 0x28, 0x3d,
                              0x3a, 0x33, 0x34, 0x4e, 0x49, 0x40, 0x47, 0x52, 0x55,
                              0x5c, 0x5b, 0x76, 0x71, 0x78, 0x7f, 0x6a, 0x6d, 0x64,
                              0x63, 0x3e, 0x39, 0x30, 0x37, 0x22, 0x25, 0x2c, 0x2b,
                              0x06, 0x01, 0x08, 0x0f, 0x1a, 0x1d, 0x14, 0x13, 0xae,
                              0xa9, 0xa0, 0xa7, 0xb2, 0xb5, 0xbc, 0xbb, 0x96, 0x91,
                              0x98, 0x9f, 0x8a, 0x8d, 0x84, 0x83, 0xde, 0xd9, 0xd0,
                              0xd7, 0xc2, 0xc5, 0xcc, 0xcb, 0xe6, 0xe1, 0xe8, 0xef,
                              0xfa, 0xfd, 0xf4, 0xf3};

  static uint8_t Compute_CRC8(uint8_t * bytes, uint8_t blen)
  {
    uint8_t crc = 0;
    int     x;

    for (x = 0; x < blen; x++)
    {
      /* XOR-in next input byte */
      uint8_t data = (uint8_t)(bytes[x] ^ crc);
      /* get current CRC value = remainder */
      crc = (uint8_t)(crcTable[data]);
    }
    return crc;
  }

#ifdef notdef
  /* http://www.sunshine2k.de/articles/coding/crc/understanding_crc.html#ch4
   */
  static void CalulateTable_CRC8()
  {
    const byte generator = 0x1D;
    crctable = new byte[256];
    /* iterate over all byte values 0 - 255 */
    for (int divident = 0; divident < 256; divident++)
    {
      byte currByte = (byte)divident;
      /* calculate the CRC-8 value for current byte */
      for (byte bit = 0; bit < 8; bit++)
      {
        if ((currByte & 0x80) != 0)
        {
          currByte <<= 1;
          currByte ^= generator;
        }
        else
        {
          currByte <<= 1;
        }
      }
      /* store CRC value in lookup table */
      crctable[divident] = currByte;
    }
  }
#endif


  si446x_packet_header_t *getHdr(message_t *msg) {
    return (si446x_packet_header_t *) (&msg->data[0] - sizeof(si446x_packet_header_t));
    // return &msg->header[offsetof(message_t, data) - sizeof(si446x_packet_header_t)];
  }

  command uint8_t   TagnetHeader.bytes_avail(message_t* msg) {
    return sizeof(msg->data);
  }

  command void    TagnetHeader.finalize(message_t *msg) {
    uint8_t    *mbuf;
    int         mlen;
    mbuf = (uint8_t *) msg;
    mlen = getHdr(msg)->frame_length;
    mbuf[mlen] = Compute_CRC8(mbuf, mlen);
    getHdr(msg)->frame_length = mlen + 1;
  }

  command bool   TagnetHeader.is_hdr_valid(message_t *msg) {
    uint8_t    *mbuf;
    int         mlen;
    uint8_t     crc;

    if (call TagnetHeader.get_version(msg) == TAGNET_VERSION) {
      mbuf = (uint8_t *) msg;
      getHdr(msg)->frame_length -= 1;
      mlen = getHdr(msg)->frame_length;
      crc = Compute_CRC8(mbuf, mlen);
      if (mbuf[mlen] == crc) {
        return TRUE;
      }
      getHdr(msg)->frame_length += 1; // reset header back
    } else if (call TagnetHeader.get_version(msg) < TAGNET_VERSION) {
      return TRUE;             // backward compatible
    }
    return FALSE;
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

  async command uint8_t   TagnetHeader.get_name_len(message_t* msg) {
    return getHdr(msg)->name_length;
  }

  command uint8_t   TagnetHeader.get_version(message_t* msg) {
    return ((getHdr(msg)->tn_h1 & TN_H1_VERS_M) >> TN_H1_VERS_B);
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

  command void   TagnetHeader.set_version(message_t *msg, uint8_t vers) {
    getHdr(msg)->tn_h1 = ((vers << TN_H1_VERS_B) & TN_H1_VERS_M)
      | (getHdr(msg)->tn_h1 & ~TN_H1_VERS_M);
  }

  async event void Panic.hook() { }
}
