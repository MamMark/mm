/**
 * Copyright (c) 2017 Daniel J. Maltbie
 * All rights reserved.
 *
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
 *
 * @author Daniel J. Maltbie <dmaltbie@daloma.org>
 *
 */

#include "TagnetTLV.h"

interface TagnetTLV {
  command uint8_t           copy_tlv(tagnet_tlv_t *t, tagnet_tlv_t *d, uint8_t limit);
  command bool              eq_tlv(tagnet_tlv_t *s, tagnet_tlv_t *t);
  command uint8_t           get_len(tagnet_tlv_t *t);      // length of the TLV
  command uint8_t           get_len_v(tagnet_tlv_t *t);    // length of the 'V' part of the TLV
  command tagnet_tlv_t     *get_next_tlv(tagnet_tlv_t *t, uint8_t limit);
  command tagnet_tlv_type_t get_tlv_type(tagnet_tlv_t *t);
  command uint8_t           integer_to_tlv(int32_t i, tagnet_tlv_t *t, uint8_t limit);
  command bool              is_special_tlv(tagnet_tlv_t *t);
  command int               repr_tlv(tagnet_tlv_t *t,  uint8_t *b, uint8_t limit);
  command uint8_t           string_to_tlv(uint8_t *s, uint8_t length, tagnet_tlv_t *t, uint8_t limit);
  command int32_t           tlv_to_integer(tagnet_tlv_t *t);
  command uint8_t          *tlv_to_string(tagnet_tlv_t *t, int *len);
}
