/**
 * This interface provides functions to access the Name field in
 * a Tagnet message.
 *<p>
 * These functions include accessors to examine an individual 
 * name element (a TLV), find special elements in the name,
 * and build a name.
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
   * Get pointer to gps_pos tlv in name
   *
   * @param   msg           pointer to message buffer containing the name
   * @return  tagnet_tlv_t  pointer to gps position tlv
   */
  command tagnet_tlv_t*    get_gps_pos(message_t *msg);
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
   * @param   msg           pointer to message buffer containing the name
   * @return  tagnet_tlv_t  pointer to node_id tlv
   */
  command tagnet_tlv_t*     get_node_id(message_t *msg);
  /**
   * Get pointer to seq_no (sequence number) tlv in name
   *
   * @param   msg           pointer to message buffer containing the name
   * @return  tagnet_tlv_t  pointer to seq_no tlv
   */
  command tagnet_tlv_t*     get_seq_no(message_t *msg);
  /**
   * Get pointer to utc_time tlv in name
   *
   * @param   msg           pointer to message buffer containing the name
   * @return  tagnet_tlv_t  pointer to utc_time tlv
   */
  command tagnet_tlv_t*     get_utc_time(message_t *msg);
  /**
   * Advance current 'this' tlv index to the next tlv in name and
   * process any special tlv types
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
   * Set index of gps_pos to current 'this' tlv
   *
   * @param   msg           pointer to message buffer containing the name
   */
  command void              set_gps_pos(message_t *msg);
  /**
   * Set index of node_id tlv to current 'this' tlv
   *
   * @param   msg           pointer to message buffer containing the name
   */
  command void              set_node_id(message_t *msg);
  /**
   * Set index of seq_no tlv to current 'this' tlv
   *
   * @param   msg           pointer to message buffer containing the name
   */
  command void              set_seq_no(message_t *msg);
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
