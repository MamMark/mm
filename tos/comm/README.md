/**
 * @Copyright (c) 2017 Daniel J. Maltbie
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

/*
 * Configurations:
 *  TagnetC
 *  TagnetNameRootP
 *  TagnetNameElementP
 *  TagnetNamePollP
 *  TagnetNameIntegerP
 *  TagnetNameStringP
 *  TagnetNameUtcTimeP
 *  TagnetNameGpsPosP
 *  TagnetNameFileP
 *  TagnetUtilsC
 *
 * Interfaces:
 *  Tagnet
 *  TagnetMessage
 *  TagnetName
 *  TagnetHeader
 *  TagnetPayload
 *  TagnetTLV
 *  TagnetInteger
 *  TagnetString
 *  TagnetGpsPos
 *  TagnetUtcTime
 *  TagnetFile
 *
 * Include Files:
 *  Tagnet.h
 *  TagnetTLV.h
 *
 * Modules:
 *  TagnetNameP
 *  TagnetHeaderP
 *  TagnetPayloadP
 *  TagnetTlvP
 *  TagnetNameElementImplP
 *  TagnetNameRootImplP
 *  TagnetNamePollImplP
 *
 */

/*
 * Tagnet Protocol BNF Description
 *
frame          =  frame_length
                  + response_flag[7:1] + version[4:3] payload_type[0:1]
                  + message_type[5:3] + options[0:5]
                  + name_length
                  + packet
frame_length   =  6..255
response_flag  =  Enum( 'REQUEST'=0, 'RESPONSE'=1 )
version        =  1
payload_type   =  Enum( 'RAW'=0 | 'TLV_LIST'=1 )
message_type   =  Enum( 'POLL'=0 | 'BEACON'=1 | 'HEAD'=2
                       | 'PUT'=3 | 'GET'=4 | 'DELETE'=5 | 'OPTION'=6  )
options        =  [error_code if (frame.response_flag) else hop_count]
name_length    =  2..251

packet         =  poll | beacon | put | get | delete | head | options
name           =  tlv | name + tlv
*(rsp)         =  (frame.response_flag set to TRUE)

poll           =  name('tag' + 'poll' + tlv_node_id(my_mac()) + 'ev')
                  + payload(tlv_time(now())
                            + tlv_integer(SLOT_TIME)   // milliseconds
                            + tlv_integer(SLOT_COUNT))
poll(rsp)      =  poll.name
                  + payload(tlv_node_id(my_mac())
                            + tlv_node_name(hostname())
                            + tlv_time(now()))
head           =  name
head(rsp)      =  head.name + payload
beacon         =  name('tag' + 'beacon' + tlv_node_id(my_mac()) + 'id')
                  + payload(tlv_list(list of tagnet_tlv_t tuples))
beacon(rsp)    =  beacon.name
                  + payload(tlv_list(list of tagnet_tlv_t tuples))
post           =  name + payload
post(rsp)      =  post.name
put            =  name + payload
put(rsp)       =  put.name
get            =  name [+  payload]
get(rsp)       =  get.name + payload
delete         =  name
delete(rsp)    =  delete.name
patch          =  name + payload
patch(rsp)     =  patch.name + payload

payload        =  raw_bytes | tlv_list
raw_bytes      =  BYTE[frame_length - name_length]

hop_count      =  1..31
error_code     =  Enum( 'OK'=0 | 'NO_ROUTE'=1 | 'TOO_MANY_HOPS'=2
                  | 'MTU_EXCEEDED'=3 | 'UNSUPPORTED'=4
                  | 'BAD_MESSAGE'=5 | 'FAILED'=6 | 'NO_MATCH'=7 )

tlv            =  tlv_type + tlv_length + tlv_value
tlv_type       =  Enum( 'NONE'=0, 'STRING'=1 | 'INTEGER'=2 | 'GPS_POS'=3
                  | 'UTC_TIME'=4 | 'NODE_ID'=5 | 'NODE_NAME'=6
                  | 'SEQ_NO'=7, 'VER_NO'=8 | 'FILE'=9 | '_COUNT'=10 )
tlv_list       =  tlv | tlv_list + tlv
tlv_length     =  0..254
tlv_value      =  is one of the following based on tlv_type
  tlv_string   =  BYTE[tlv_length]
  tlv_integer  =  BYTE[tlv_length]   // scales 1..n(value)
  tlv_datetime =  temporenc          // encoded [YYYY-MM-DD HH:MM:SS.UUUUUU]
  tlv_node_id  =  BYTE[6]
  tlv_node_name=  tlv_string
  tlv_tlv      =  tlv_list
  tlv_offset   =  tlv_integer
  tlv_count    =  tlv_integer

*/
