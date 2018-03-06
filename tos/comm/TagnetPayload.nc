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
 * Accessor functions to the payload in a Tagnet message.
 *<p>
 * These functions work on the payload of a message. The payload can
 * contain a raw byte field or a list of tlvs, which is designated in
 * the message header.
 *</p>
 *<p>
 * Since both request and response messages optionally contain payloads,
 * there are functions for adding data as well as retrieving it.
 *</p>
 * zzz tbd: need to add accessor function to get pointer to raw bytes.
 */

#include <image_info.h>

interface TagnetPayload {
  /**
   * Adds a block of bytes (byte string) to the payload (wrapping
   * it in a tlv). Sets the payload type to list of tlvs
   *
   * @param   msg           pointer to message buffer containing the payload
   * @param   b             bytestring to be added to the payload as a tlv
   * @return  uint8_t       amount added to the payload (length of tlv)
   */
  command uint8_t           add_block(message_t *msg, void *b, uint8_t length);
  /**
   * Adds a retry delay value (millisec) to the payload (wrapping it in a
   * tlv). Sets the payload type to list of tlvs
   *
   * @param   msg           pointer to message buffer containing the payload
   * @param   n             delay to be added to the payload as a tlv
   * @return  uint8_t       amount added to the payload (length of tlv)
   */
  command uint8_t           add_delay(message_t *msg,  uint32_t n);
  /**
   * Adds an eof value to the payload. Sets the payload type to list of tlvs
   *
   * @param   msg           pointer to message buffer containing the payload
   * @return  uint8_t       amount added to the payload (length of tlv)
   */
  command uint8_t           add_eof(message_t *msg);
  /**
   * Adds an app error value to the payload. Sets the payload type to list of tlvs
   *
   * @param   msg           pointer to message buffer containing the payload
   * @param   err           app error code to be added to the payload as a tlv
   * @return  uint8_t       amount added to the payload (length of tlv)
   */
  command uint8_t           add_error(message_t *msg, int32_t err);
  /**
   * Adds an gps_xyz value to the payload (wrapping it in a tlv). Sets the
   * payload type to list of tlvs
   *
   * @param   msg           pointer to message buffer containing the payload
   * @param   xyz           pointer to gps_xyz to be added to payload as tlv
   * @return  uint8_t       amount added to the payload (length of tlv)
   */
  command uint8_t           add_gps_xyz(message_t *msg, tagnet_gps_xyz_t *xyz);
  /**
   * Adds an integer value to the payload (wrapping it in a tlv). Sets the
   * payload type to list of tlvs
   *
   * @param   msg           pointer to message buffer containing the payload
   * @param   n             integer to be added to the payload as a tlv
   * @return  uint8_t       amount added to the payload (length of tlv)
   */
  command uint8_t           add_integer(message_t *msg,  int32_t n);
  /**
   * Adds a file offset value to the payload (wrapping it in a tlv). Sets the
   * payload type to list of tlvs
   *
   * @param   msg           pointer to message buffer containing the payload
   * @param   n             offset to be added to the payload as a tlv
   * @return  uint8_t       amount added to the payload (length of tlv)
   */
  command uint8_t           add_offset(message_t *msg,  int32_t n);
  /**
   * Adds raw bytes to the payload.
   * This overwrites any other data in the payload and set payload type.
   * Will also copy data to msg if non-null buffer is passed in. otherwise,
   * just sets the length and payload type.
   *
   * @param   msg           pointer to message buffer containing the payload
   * @param   b             pointer to buffer of data (if null, then no copy)
   * @param   n             integer to be added to the payload as a tlv
   * @return  uint8_t       amount added to the payload (length of tlv)
   */
  command uint8_t           add_raw(message_t *msg, uint8_t *b, uint8_t length);
  /**
   * Adds a string to the payload (wrapping it in a tlv). Sets the
   * payload type to list of tlvs
   *
   * @param   msg           pointer to message buffer containing the payload
   * @param   b             bytestring to be added to the payload as a tlv
   * @return  uint8_t       amount added to the payload (length of tlv)
   */
  command uint8_t           add_string(message_t *msg, void *b, uint8_t length);
  /**
   * Adds an size value to the payload (wrapping it in a tlv). Sets the
   * payload type to list of tlvs
   *
   * @param   msg           pointer to message buffer containing the payload
   * @param   n             size value to be added to the payload as a tlv
   * @return  uint8_t       amount added to the payload (length of tlv)
   */
  command uint8_t           add_size(message_t *msg,  int32_t n);
  /**
   * Adds a tlv to the payload, (copies it)
   *
   * @param   msg           pointer to message buffer containing the payload
   * @param   t             tlv to be added to the payload
   * @return  uint8_t       amount added to the payload (length of tlv)
   */
  command uint8_t           add_tlv(message_t *msg, tagnet_tlv_t *t);
  /**
   * Adds a version to the payload, (copies it)
   *
   * @param   msg           pointer to message buffer containing the payload
   * @param   v             pointer to version to be added to the payload
   * @return  uint8_t       amount added to the payload (length of tlv)
   */
  command uint8_t           add_version(message_t *msg, image_ver_t *v);
  /**
   * Returns the amount of free space in the message buffer, accounting for any
   * name and payload data previously added to the message. This is the free
   * buffer space remaining to hold additional data.
   *
   * @param   msg           pointer to message buffer containing the payload
   * @return  uint8_t       amount free in buffer
   */
  command uint8_t           bytes_avail(message_t* msg);  // unused bytes in the buffer
  /**
   * Returns pointer to the first element in the payload. If payload is raw bytes then returns NULL
   *
   * @param   msg           pointer to message buffer containing the payload
   * @return  tagnet_tlv_t  point to first tlv
   */
  command tagnet_tlv_t     *first_element(message_t *msg);
  /**
   * Returns the length of the payload. This is message length - name & header length
   *
   * @param   msg           pointer to message buffer containing the payload
   * @return  uint8_t       length of the payload
   */
  command uint8_t           get_len(message_t* msg);
  /**
   * Returns the pointer to the 'next' tlv in the payload (automatically advances to the 'next' based on 'this')
   *
   * @param   msg           pointer to message buffer containing the payload
   * @return  tagnet_tlv_t  pointer to next tlv
   */
  command tagnet_tlv_t     *next_element(message_t *msg);
  /**
   * Resets the payload to emtpy state. Perform this function before starting to add data to response message
   *
   * @param   msg           pointer to message buffer containing the payload
   */
  command void              reset_payload(message_t* msg);
  /**
   * Returns pointer to the current 'this' tlv
   *
   * @param   msg           pointer to message buffer containing the payload
   * @return  tagnet_tlv_t  pointer to 'this' tlv
   */
  command tagnet_tlv_t     *this_element(message_t *msg);
}
