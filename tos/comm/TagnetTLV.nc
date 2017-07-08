/**
 * Accessor functions for Tagnet TLV handling
 *<p>
 * These functions manipulate the Tagnet Type-Length-Value (TLV) data type.
 * The Tagnet tlv type is used in constructing both the name and payload fields
 * in the Tagnet message.These functions handle the conversion from native
 * C types to a network friendly, compressed format and back again.<br>
 * Users should NOT access the TLV contents directly.
 *</p>
 *
 * @author Daniel J. Maltbie <dmaltbie@daloma.org>
 *
 * @Copyright (c) 2017 Daniel J. Maltbie
 * All rights reserved.
 */
/*
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
 */

#include "TagnetTLV.h"

interface TagnetTLV {
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
  command uint8_t           copy_tlv(tagnet_tlv_t *t, tagnet_tlv_t *d, uint8_t limit);
  /**
   * Check to see if two tlvs match. All fields are compared
   *
   * @param   s             point to first tlv
   * @param   t             point to second tlv
   * @return  bool         TRUE if tlvs exactly match
   */
  command bool              eq_tlv(tagnet_tlv_t *s, tagnet_tlv_t *t);
  /**
   * Get length of entire tlv, including all three fields
   *
   * @param   t             pointer to tlv
   * @return  uint8_t       total tlv length
   */
  command uint8_t           get_len(tagnet_tlv_t *t);
  /**
   * Get length of the tlv val field only
   *
   * @param   t             pointer to tlv
   * @return  uint8_t       value of tlv length field
   */
  command uint8_t           get_len_v(tagnet_tlv_t *t);
  /**
   * Get pointer to the next tlv. This is determined by advancing the pointer
   * to the input tlv by adding its length and the fixed header size. Various
   * checks are performed on the target address to validate contents as a tlv.
   *
   * @param   t             pointer of tlv to use as starting point
   * @param   limit         limit to how far tlv pointer can be advanced
   * @return  tagnet_tlv_t  pointer to next tlv. NULL if no valid tlv found or beyond limit
   */
  command tagnet_tlv_t     *get_next_tlv(tagnet_tlv_t *t, uint8_t limit);
  /**
   * Get the type of a tlv
   *
   * @param   t             pointer of tlv of interest
   * @return  tagnet_tlv_type_t value of the tlv type found
   */
  command tagnet_tlv_type_t get_tlv_type(tagnet_tlv_t *t);
  /**
   * Convert integer value into a Tagnet TLV and store in destination location
   *
   * @param   i             integer value to store in the tlv
   * @param   t             pointer of tlv to use as destination location
   * @param   limit         maximum bytes available at destination tlv
   * @return  uint8_t       number of bytes stored in destination
   */
  command uint8_t           integer_to_tlv(int32_t i, tagnet_tlv_t *t, uint8_t limit);
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
   * like gps_pos and utc_time.
   *
   * @param   t             pointer of tlv to represent
   * @param   b             pointer to buffer where to place the ascii representation
   * @param   limit         maximum bytes available at destination buffer
   * @return  uint8_t       length of new tlv
   */
  command int               repr_tlv(tagnet_tlv_t *t,  uint8_t *b, uint8_t limit);
  /**
   * Copy the string to the tlv
   *
   * @param   s             pointer to string to be copied
   * @param   length        number of bytes to copy from source
   * @param   t             pointer of where to place the copy
   * @param   limit         maximum bytes available at destination buffer
   * @return  uint8_t       length of new tlv
   */
  command uint8_t           string_to_tlv(uint8_t *s, uint8_t length, tagnet_tlv_t *t, uint8_t limit);
  /**
   * Convert tlv to integer. tlv must be an integer tlv tagnet type
   *
   * @param   t             pointer of tlv to convert
   * @return  uint8_t       integer value from tlv. zero if can't be converted
   */
  command int32_t           tlv_to_integer(tagnet_tlv_t *t);
  /**
   * Convert tlv to string. tlv must be an integer tlv tagnet type
   *
   * @param   t             pointer of tlv to convert
   * @param   len           pointer to int for returning length of string
   * @return  uint8_t       pointer to string
   */
  command uint8_t          *tlv_to_string(tagnet_tlv_t *t, int *len);
}
