/**
 * Copyright @ 2017 Daniel J. Maltbie
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
 * @author Daniel J. Maltbie (dmaltbie@daloma.org)
 */

#ifndef __TAGNETTLV__
#define __TAGNETTLV__

/*
 * Tagnet TLV Types
 */

typedef enum {
  TN_TLV_NONE=0,
  TN_TLV_STRING=1,
  TN_TLV_INTEGER=2,
  TN_TLV_GPS_POS=3,
  TN_TLV_UTC_TIME=4,
  TN_TLV_NODE_ID=5,
  TN_TLV_NODE_NAME=6,
  TN_TLV_SEQ_NO=7,
  TN_TLV_VER_NO=8,
  TN_TLV_FILE=9,
  _TN_TLV_COUNT   // limit of  enum
} tagnet_tlv_type_t;

typedef struct tagnet_tlv_t {
  tagnet_tlv_type_t typ;
  uint8_t           len;
  uint8_t           val[];
} tagnet_tlv_t;

#endif
