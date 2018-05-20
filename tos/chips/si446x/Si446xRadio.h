/*
 * Copyright (c) 2015-2018  Eric B. Decker, Daniel J. Maltbie
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
 * Author: Eric B. Decker <cire831@gmail.com>
 *         December 2015.
 * Author: Daniel J. Maltbie <dmaltbie>
 *         May 2017.
 */

#ifndef __SI446XRADIO_H__
#define __SI446XRADIO_H__

#include <MetadataFlagsLayer.h>

#ifdef notdef
#include <TimeStampingLayer.h>
#endif

#define UQ_SI446X_METADATA_FLAGS "UQ_SI446X_METADATA_FLAGS"
#define UQ_SI446X_RADIO_ALARM    "UQ_SI446X_RADIO_ALARM"

/**
 * SI446X packet definition.
 *
 */

/*
 * si446x_packet_header
 * contains first the PHR (PHY Hdr), which consists of the
 * frame_length, counting all of the MPDU bytes in the
 * transmission. The CRC at the end of the frame is not
 * included in the frame_length.
 *
 * The rest of the packet header consists of the Tagnet
 * fixed field, providing basic Tagnet message information.
 *
 * The packet header length total is 4 bytes.
 *
 * packet  = frame_length,
 *           tn_h1(response_flag[1],
 *                 version[3],
 *                 padding[3],
 *                 payload_type[1]),
 *           tn_h2(packet_type[3],
 *                 options[5]),
 *           name_length,
 *           payload (*n bytes),
 *           crc     (*only stored on chip)
 */

typedef nx_struct si446x_packet_header {
  nxle_uint8_t            frame_length;
  nxle_uint8_t            tn_h1;
  nxle_uint8_t            tn_h2;
  nxle_uint8_t            name_length;
} si446x_packet_header_t;

#define TN_H1_RSP_F_M      0x80  // (h1)[7:1] response flag
#define TN_H1_RSP_F_B      7

#define TN_H1_VERS_M       0x70  // (h1)[4:3] version
#define TN_H1_VERS_B       4

#define TN_H1_PL_TYPE_M    0x01  // (h1)[0:1] payload type
#define TN_H1_PL_TYPE_B    0

#define TN_H2_MTYPE_M      0xE0  // (h2)[5:3] message type
#define TN_H2_MTYPE_B      5

#define TN_H2_OPTION_M     0x1F  // (h2)[0:5] option
#define TN_H2_OPTION_B     0


typedef nx_struct si446x_packet_footer {
  nx_uint8_t  placeholder;
  nx_uint8_t  placeholder2;
} si446x_packet_footer_t;

/**
 * SI446X Packet metadata. Contains extra information about the message
 * that will not be transmitted.
 */
typedef struct si446x_metadata_t {
  //uint16_t rxInterval;
  uint16_t   tx_delay;
  uint8_t    rssi;
  uint8_t    tx_power;
  //bool     timesync;
} si446x_metadata_t;


typedef nx_struct si446x_packet_t {
  si446x_packet_header_t packet;
  nx_uint8_t data[];
} si446x_packet_t;


#ifndef TOSH_DATA_LENGTH
#define TOSH_DATA_LENGTH 250
#endif

/**
 * Ideally, your receive history size should be equal to the number of
 * RF neighbors your node will have
 */
#ifndef RECEIVE_HISTORY_SIZE
#define RECEIVE_HISTORY_SIZE 4
#endif

enum {
  // size of the header not including the length byte
  MAC_HEADER_SIZE = sizeof( si446x_packet_header_t ) - 1,

  // size of the FCS field
  MAC_FOOTER_SIZE = 0,

  // MPDU
  MAC_PACKET_SIZE = MAC_HEADER_SIZE + TOSH_DATA_LENGTH + MAC_FOOTER_SIZE,

  SI446X_MIN_SIZE = MAC_HEADER_SIZE + MAC_FOOTER_SIZE,
};

#endif          //__SI446XRADIO_H__
