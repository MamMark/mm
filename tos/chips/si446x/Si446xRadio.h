/*
 * Copyright (c) 2015-2016, Eric B. Decker
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
 * Author: Eric B. Decker <cire831@gmail.com>
 */

#ifndef __SI446XRADIO_H__
#define __SI446XRADIO_H__

#include <RadioConfig.h>
#include <TinyosNetworkLayer.h>
#include <Ieee154PacketLayer.h>
#include <ActiveMessageLayer.h>
#include <MetadataFlagsLayer.h>
#include <Si446xDriverLayer.h>
#include <TimeStampingLayer.h>
#include <LowPowerListeningLayer.h>
#include <PacketLinkLayer.h>

#if defined(TFRAMES_ENABLED) && defined(IEEE154FRAMES_ENABLED)
#error "Both TFRAMES and IEEE154FRAMES enabled!"
#endif


/**
 * SI446X header definition.
 *
 * The si446x family of chips are very flexible.  We default to
 * a simple 802.15.4 like packet format for compatibility with existing
 * TinyOS 802.15.4 stacks.
 * 
 * An I-frame (interoperability frame) header has an extra network 
 * byte specified by 6LowPAN
 * 
 * Length = length of the header + payload of the packet, minus the size
 *   of the length byte itself (1).  This is what allows for variable 
 *   length packets.
 * 
 * FCF = Frame Control Field, defined in the 802.15.4 specs and the
 *   SI446X datasheet.
 *
 * DSN = Data Sequence Number, a number incremented for each packet sent
 *   by a particular node.  This is used in acknowledging that packet, 
 *   and also filtering out duplicate packets.
 *
 * DestPan = The destination PAN (personal area network) ID, so your 
 *   network can sit side by side with another TinyOS network and not
 *   interfere.
 * 
 * Dest = The destination address of this packet. 0xFFFF is the broadcast
 *   address.
 *
 * Src = The local node ID that generated the message.
 * 
 * Network = The TinyOS network ID, for interoperability with other types
 *   of 802.15.4 networks. 
 * 
 * Type = TinyOS AM type.  When you create a new AMSenderC(AM_MYMSG), 
 *   the AM_MYMSG definition is the type of packet.
 * 
 * TOSH_DATA_LENGTH defaults to 28, it represents the maximum size of 
 * the payload portion of the packet, and is specified in the 
 * tos/types/message.h file.
 *
 * All of these fields will be filled in automatically by the radio stack 
 * when you attempt to send a message.
 */

/*
 * si446x_packet_header contains first the PHR (PHY Hdr), Length
 * and then the MPDU header (ieee154).   The ieee154 header
 * is actually a simple 802.15.4 header that only has 16 bit
 * addresses and a dpan (compressed PAN id).
 *
 * depending on defines we may also have a network byte as
 * an am_type ("am").
 */

typedef nx_struct si446x_packet_header {
  nxle_uint8_t            length;
  ieee154_simple_header_t ieee154;

#ifndef TFRAMES_ENABLED
  network_header_t        network;
#endif
#ifndef IEEE154FRAMES_ENABLED
  activemessage_header_t  am_type;
#endif
} si446x_packet_header_t;


typedef nx_struct si446x_packet_footer {
  // the time stamp is not recorded here, time stamped messages cannot have max length
  // which means what?
} si446x_packet_footer_t;

/**
 * SI446X Packet metadata. Contains extra information about the message
 * that will not be transmitted.
 */
typedef struct si446x_metadata_t {
  uint16_t rxInterval;
  uint8_t  rssi;
  uint8_t  lqi;
  uint8_t  tx_power;
  bool     crc;
  bool     ack;
  bool     timesync;
} si446x_metadata_t;


typedef nx_struct si446x_packet_t {
  si446x_packet_header_t packet;
  nx_uint8_t data[];
} si446x_packet_t;


#ifndef TOSH_DATA_LENGTH
#define TOSH_DATA_LENGTH 28
#endif

/**
 * Ideally, your receive history size should be equal to the number of
 * RF neighbors your node will have
 */
#ifndef RECEIVE_HISTORY_SIZE
#define RECEIVE_HISTORY_SIZE 4
#endif


/** 
 * The 6LowPAN NALP ID for a TinyOS network is 63 (TEP 125).
 */
#ifndef TINYOS_6LOWPAN_NETWORK_ID
#define TINYOS_6LOWPAN_NETWORK_ID 0x3f
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
