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
 * Accessor functions for Tagnet TLV handling
 *<p>
 * These functions manipulate the Tagnet Type-Length-Value (TLV) data type.
 * The Tagnet tlv type is used in constructing both the name and payload fields
 * in the Tagnet message.These functions handle the conversion from native
 * C types to a network friendly, compressed format and back again.<br>
 * Users should NOT access the TLV contents directly.
 *</p>
 */

#include "TagnetTLV.h"

interface TagnetTLV {
  /**
   * Convert a byte array into the tlv
   *
   * @param   s             pointer to byte array to be copied
   * @param   length        number of bytes to copy from source
   * @param   t             pointer of where to place the copy
   * @param   limit         maximum bytes available at destination buffer
   * @return  uint32_t      length of new tlv
   */
  command uint32_t           block_to_tlv(uint8_t *s, uint32_t length, tagnet_tlv_t *t, uint32_t limit);
  /**
   * Copy a tlv to another location. The copy length is determined from
   * the source tlv. A limit parameter is also passed to determine if
   * the destination is not large enough to hold the source tlv
   *
   * @param   t             pointer to source tlv
   * @param   d             pointer to destination tlv
   * @param   limit         maximum bytes available at destination tlv
   * @return  uint8_t       total number of bytes copied
   */
  command uint32_t          copy_tlv(tagnet_tlv_t *t, tagnet_tlv_t *d, uint32_t limit);
  /**
   * Convert rtctime value into a Tagnet TLV and store in destination location
   *
   * @param   v             rtctime value to store in the tlv
   * @param   t             pointer of tlv to use as destination location
   * @param   limit         maximum bytes available at destination tlv
   * @return  uint32_t      number of bytes stored in destination
   */
  command uint32_t          rtctime_to_tlv(rtctime_t *v, tagnet_tlv_t *t, uint32_t limit);
  /**
   * Convert delay value into a Tagnet TLV and store in destination location
   *
   * @param   i             integer value to store in the tlv
   * @param   t             pointer of tlv to use as destination location
   * @param   limit         maximum bytes available at destination tlv
   * @return  uint32_t      number of bytes stored in destination
   */
  command uint32_t          delay_to_tlv(int32_t i, tagnet_tlv_t *t, uint32_t limit);
  /**
   * Check to see if two tlvs match. All fields are compared
   *
   * @param   s            point to first tlv
   * @param   t            point to second tlv
   * @return  bool         TRUE if tlvs exactly match
   */
  async command bool             eq_tlv(tagnet_tlv_t *s, tagnet_tlv_t *t);
  /**
   * Convert error value into a Tagnet TLV and store in destination location
   *
   * @param   err           error value to store in the tlv
   * @param   t             pointer of tlv to use as destination location
   * @param   limit         maximum bytes available at destination tlv
   * @return  uint32_t      number of bytes stored in destination
   */
  command uint32_t          error_to_tlv(int32_t err, tagnet_tlv_t *t, uint32_t limit);
  /**
   * Get length of entire tlv, including all three fields
   *
   * @param   t             pointer to tlv
   * @return  uint32_t      total tlv length
   */
  command uint32_t          get_len(tagnet_tlv_t *t);
  /**
   * Get length of the tlv val field only
   *
   * @param   t             pointer to tlv
   * @return  uint32_t      value of tlv length field
   */
  command uint32_t          get_len_v(tagnet_tlv_t *t);
  /**
   * Get pointer to the next tlv. This is determined by advancing the pointer
   * to the input tlv by adding its length and the fixed header size. Various
   * checks are performed on the target address to validate contents as a tlv.
   *
   * @param   t             pointer of tlv to use as starting point
   * @param   limit         limit to how far tlv pointer can be advanced
   * @return  tagnet_tlv_t  pointer to next tlv. NULL if no valid tlv found or beyond limit
   */
  command tagnet_tlv_t     *get_next_tlv(tagnet_tlv_t *t, uint32_t limit);
  /**
   * Get the type of a tlv
   *
   * @param   t             pointer of tlv of interest
   * @return  tagnet_tlv_type_t value of the tlv type found
   */
  async command tagnet_tlv_type_t get_tlv_type(tagnet_tlv_t *t);
  /**
   * Convert gps_xyz value into a Tagnet TLV and store in destination location
   *
   * @param   xyz           gps_xyz value to store in the tlv
   * @param   t             pointer of tlv to use as destination location
   * @param   limit         maximum bytes available at destination tlv
   * @return  uint32_t      number of bytes stored in destination
   */
  command uint32_t          gps_xyz_to_tlv(tagnet_gps_xyz_t *xyz, tagnet_tlv_t *t, uint32_t limit);
  /**
   * Convert integer value into a Tagnet TLV and store in destination location
   *
   * @param   i             integer value to store in the tlv
   * @param   t             pointer of tlv to use as destination location
   * @param   limit         maximum bytes available at destination tlv
   * @return  uint32_t      number of bytes stored in destination
   */
  command uint32_t          integer_to_tlv(int32_t i, tagnet_tlv_t *t, uint32_t limit);
  /**
   * Convert file offset value into a Tagnet TLV and store in destination location
   *
   * @param   i             integer value to store in the tlv
   * @param   t             pointer of tlv to use as destination location
   * @param   limit         maximum bytes available at destination tlv
   * @return  uint32_t      number of bytes stored in destination
   */
  command uint32_t          offset_to_tlv(int32_t i, tagnet_tlv_t *t, uint32_t limit);
  /**
   * Convert file size value into a Tagnet TLV and store in destination location
   *
   * @param   i             integer value to store in the tlv
   * @param   t             pointer of tlv to use as destination location
   * @param   limit         maximum bytes available at destination tlv
   * @return  uint32_t      number of bytes stored in destination
   */
  command uint32_t          size_to_tlv(int32_t i, tagnet_tlv_t *t, uint32_t limit);
  /**
   * Determine if this tlv needs to be handled specially
   *
   * @param   t            pointer of tlv to check
   * @return  bool         TRUE if special
   */
  command bool              is_special_tlv(tagnet_tlv_t *t);
  /**
   * Represent the tlv in a human readable format. For instance, non-printable
   * characters in a string are made printable. Integers are represented as
   * ascii numbers. Other fields have representations appropriate to their type,
   * like gps_xyz and utc_time.
   *
   * @param   t             pointer of tlv to represent
   * @param   b             pointer to buffer where to place the ascii representation
   * @param   limit         maximum bytes available at destination buffer
   * @return  uint32_t      length of new tlv
   */
  command int               repr_tlv(tagnet_tlv_t *t,  uint8_t *b, uint32_t limit);
  /**
   * Copy the string to the tlv
   *
   * @param   s             pointer to string to be copied
   * @param   length        number of bytes to copy from source
   * @param   t             pointer of where to place the copy
   * @param   limit         maximum bytes available at destination buffer
   * @return  uint32_t      length of new tlv
   */
  command uint32_t           string_to_tlv(uint8_t *s, uint32_t length, tagnet_tlv_t *t, uint32_t limit);
  /**
   * Convert tlv to block. tlv must be a data_block tlv tagnet type
   *
   * @param   t             pointer of tlv to convert
   * @param   len           pointer to int for returning length of string
   * @return  uint8_t*      pointer to string  (limited access to life of msg)
   */
  command uint8_t          *tlv_to_block(tagnet_tlv_t *t, uint32_t *len);
  /**
   * Convert tlv to delay value (ms). tlv must be an delay tlv tagnet type
   *
   * @param   t             pointer of tlv to convert
   * @return  uint32_t      integer value from tlv. zero if can't be converted
   */
  command int32_t           tlv_to_delay(tagnet_tlv_t *t);
  /**
   * Convert tlv to rtctime. tlv must be a rtctime tlv tagnet type
   *
   * @param   t             pointer of tlv to convert
   * @return  rtctime_t     pointer to rtctime (limited access to life of msg)
   */
  command rtctime_t       *tlv_to_rtctime(tagnet_tlv_t *t);
  /**
   * Convert tlv to rtctime. tlv must be a rtctime tlv tagnet type
   *
   * @param   t             pointer of tlv to convert
   * @return  uint8_t*      pointer to node_id (limited access to life of msg)
   */
  command uint8_t          *tlv_to_node_id(tagnet_tlv_t *t);
  /**
   * Convert tlv to node_name. tlv must be a node_name tlv tagnet type
   *
   * @param   t             pointer of tlv to convert
   * @return  uint8_t*      pointer to node_name (limited access to life of msg)
   */
  command uint8_t          *tlv_to_node_name(tagnet_tlv_t *t);
  /**
   * Convert tlv to integer. tlv must be an integer tlv tagnet type
   *
   * @param   t             pointer of tlv to convert
   * @return  int32_t       integer value from tlv. zero if can't be converted
   */
  command int32_t           tlv_to_error(tagnet_tlv_t *t);
  /**
   * Convert tlv to integer. tlv must be an integer tlv tagnet type
   *
   * @param   t             pointer of tlv to convert
   * @return  int32_t       integer value from tlv. zero if can't be converted
   */
  command int32_t           tlv_to_integer(tagnet_tlv_t *t);
  /**
   * Convert tlv to file offset (int32). tlv must be an offset tlv tagnet type
   *
   * @param   t             pointer of tlv to convert
   * @return  uint32_t      integer value from tlv. zero if can't be converted
   */
  command int32_t           tlv_to_offset(tagnet_tlv_t *t);
  /**
   * Convert tlv to file size (int32). tlv must be a size tlv tagnet type
   *
   * @param   t             pointer of tlv to convert
   * @return  uint32_t      integer value from tlv. zero if can't be converted
   */
  command int32_t           tlv_to_size(tagnet_tlv_t *t);
  /**
   * Convert tlv to string. tlv must be a string tlv tagnet type
   *
   * @param   t             pointer of tlv to convert
   * @param   len           pointer to int for returning length of string
   * @return  uint8_t*      pointer to string  (limited access to life of msg)
   */
  command uint8_t          *tlv_to_string(tagnet_tlv_t *t, uint32_t *len);
  /**
   * Convert tlv to version. tlv must be a version tlv tagnet type
   *
   * @param   t             pointer of tlv to convert
   * @return  image_ver_t   pointer to version (limited access to life of msg)
   */
  command image_ver_t      *tlv_to_version(tagnet_tlv_t *t);
  /**
   * Convert software version value into a Tagnet TLV and store in destination location
   *
   * @param   v             software version value to store in the tlv
   * @param   t             pointer of tlv to use as destination location
   * @param   limit         maximum bytes available at destination tlv
   * @return  uint32_t      number of bytes stored in destination
   */
  command uint32_t          version_to_tlv(image_ver_t *v, tagnet_tlv_t *t, uint32_t limit);
}
