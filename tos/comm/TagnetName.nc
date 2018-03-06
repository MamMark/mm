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
 * This interface provides functions to access the Name field in
 * a Tagnet message.
 *<p>
 * These functions include accessors to examine an individual
 * name element (a TLV), find special elements in the name,
 * and build a name.
 *</p>
 */

#include "message.h"
#include "Tagnet.h"
#include "TagnetTLV.h"

interface TagnetName {
  /**
   * Add a name tlv element to the end of the current name in the message.
   * Name length in header is automatically updated.
   *
   * @param   msg           pointer to message buffer containing the name
   * @param   t             pointer to the tlv to be added
   * @return  uint8_t       amount added to the name (length of tlv).
   */
  command uint8_t           add_element(message_t* msg, tagnet_tlv_t* t);
  /**
   * Amount of free room left in the message buffer (buf_size-(name+payload))
   *
   * @param   msg           pointer to message buffer containing the name
   * @return  uint8_t       amount of free space available
   */
  command uint8_t           bytes_avail(message_t* msg);
  /**
   * Get pointer to first tlv in name
   *
   * @param   msg           pointer to message buffer containing the name
   * @return  tagnet_tlv_t  pointer to first tlv
   */
  command tagnet_tlv_t*    first_element(message_t *msg);
  /**
   * Get pointer to gps_xyz tlv in name
   *
   * This is a special TLV in that its location is remembered but
   * parsing returns it as the next name TLV to process.
   *
   * @param   msg           pointer to message buffer containing the name
   * @return  tagnet_tlv_t  pointer to gps xyz position tlv
   */
  command tagnet_tlv_t*    get_gps_xyz(message_t *msg);
  /**
   * Get length of name in message
   *
   * @param   msg           pointer to message buffer containing the name
   * @return  uint8_t       length of name in message
   */
  command uint8_t           get_len(message_t* msg);
  /**
   * Get pointer to node_id tlv in name
   *
   * This is a special TLV in that its location is remembered but
   * parsing returns it as the next name TLV to process.
   *
   * @param   msg           pointer to message buffer containing the name
   * @return  tagnet_tlv_t  pointer to node_id tlv
   */
  command tagnet_tlv_t*     get_node_id(message_t *msg);
  /**
   * Get pointer to byte offset tlv in name
   *
   * This is a special TLV in that it is "consumed" when parsing the
   * name. That is, its location is remembered and parsing continues.
   *
   * @param   msg           pointer to message buffer containing the name
   * @return  tagnet_tlv_t  pointer to offset tlv
   */
  command tagnet_tlv_t*     get_offset(message_t *msg);
  /**
   * Get pointer to size tlv in name
   *
   * This is a special TLV in that it is "consumed" when parsing the
   * name. That is, its location is remembered and parsing continues.
   *
   * @param   msg           pointer to message buffer containing the name
   * @return  tagnet_tlv_t  pointer to size tlv
   */
  command tagnet_tlv_t*     get_size(message_t *msg);
  /**
   * Get pointer to version tlv in name
   *
   * This is a special TLV in that it is "consumed" when parsing the
   * name. That is, its location is remembered and parsing continues.
   *
   * @param   msg           pointer to message buffer containing the name
   * @return  tagnet_tlv_t  pointer to version tlv
   */
  command tagnet_tlv_t*     get_version(message_t *msg);
  /**
   * Get pointer to utc_time tlv in name
   *
   * This is a special TLV in that its location is remembered but
   * parsing returns it as the next name TLV to process.
   *
   * @param   msg           pointer to message buffer containing the name
   * @return  tagnet_tlv_t  pointer to utc_time tlv
   */
  command tagnet_tlv_t*     get_utc_time(message_t *msg);
  /**
   * Get the next tlv in the name
   *
   * @param   msg           pointer to message buffer containing the name
   * @return  bool          TRUE if this is the last element of name
   */
  command bool              is_last_element(message_t *msg);
  /**
   * Get the next tlv in the name
   *
   * @param   msg           pointer to message buffer containing the name
   * @return  tagnet_tlv_t  pointer to next tlv element in name
   */
  command tagnet_tlv_t*     next_element(message_t *msg);
  /**
   * Reset message so that a new name can be added
   *
   * @param   msg           pointer to message buffer containing the name
   */
  command void              reset_name(message_t* msg);
  /**
   * Set index of gps_xyz to current 'this' tlv
   *
   * @param   msg           pointer to message buffer containing the name
   */
  command void              set_gps_xyz(message_t *msg);
  /**
   * Set index of node_id tlv to current 'this' tlv
   *
   * @param   msg           pointer to message buffer containing the name
   */
  command void              set_node_id(message_t *msg);
  /**
   * Set index of offset tlv to current 'this' tlv
   *
   * @param   msg           pointer to message buffer containing the name
   */
  command void              set_offset(message_t *msg);
  /**
   * Set index of size tlv to current 'this' tlv
   *
   * @param   msg           pointer to message buffer containing the name
   */
  command void              set_size(message_t *msg);
  /**
   * Set index of version tlv to current 'this' tlv
   *
   * @param   msg           pointer to message buffer containing the name
   */
  command void              set_version(message_t *msg);
  /**
   * Set index of utc_time tlv to current 'this' tlv
   *
   * @param   msg           pointer to message buffer containing the name
   */
  command void              set_utc_time(message_t *msg);
  /**
   * Get pointer to current 'this' tlv
   *
   * @param   msg           pointer to message buffer containing the name
   * @return  tagnet_tlv_t  pointer to first tlv
   */
  command tagnet_tlv_t*     this_element(message_t *msg);
}
