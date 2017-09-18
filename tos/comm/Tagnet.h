/*
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
 */

#ifndef __TAGNET_H__
#define __TAGNET_H__

typedef enum {
  TN_POLL                = 0,
  TN_BEACON              = 1,
  TN_HEAD                = 2,
  TN_PUT                 = 3,
  TN_GET                 = 4,
  TN_DELETE              = 5,
  TN_OPTION              = 6,
  TN_RESERVED            = 7, // maximum of seven types
  _TN_COUNT              // limit of enum
} tagnet_msg_type_t;

typedef enum {
  TE_PKT_OK              = 0,
  TE_NO_ROUTE,
  TE_TOO_MANY_HOPS,
  TE_MTU_EXCEEDED,
  TE_UNSUPPORTED,
  TE_BAD_MESSAGE,
  TE_FAILED,
  TE_PKT_NO_MATCH,
  TE_BUSY,
} tagnet_error_t;

typedef struct tagnet_name_meta_t {
  uint8_t     this;
  uint8_t     offset;
  uint8_t     version;
  uint8_t     size;
  uint8_t     utc_time;
  uint8_t     node_id;
  uint8_t     gps_xyz;
} tagnet_name_meta_t;

typedef struct tagnet_payload_meta_t {
  uint8_t     this;
} tagnet_payload_meta_t;

// unique ids used for wiring to generic modules
#define UQ_TN_ROOT              "UQ_TN_ROOT"
#define UQ_TN_TAG               "UQ_TN_TAG"
#define UQ_TN_POLL              "UQ_TN_POLL"
#define UQ_TN_POLL_NID          "UQ_TN_POLL_NID"
#define UQ_TN_POLL_EV           "UQ_TN_POLL_EV"
#define UQ_TN_POLL_CNT          "UQ_TN_POLL_CNT"
#define UQ_TN_SENS              "UQ_TN_SENS"
#define UQ_TN_SENS_GPS          "UQ_TN_SENS_GPS"
#define UQ_TN_SENS_GPS_XYZ      "UQ_TN_SENS_GPS_XYZ"
#define UQ_TN_INFO              "UQ_TN_INFO"
#define UQ_TN_INFO_NID          "UQ_TN_INFO_NID"
#define UQ_TN_INFO_SENS         "UQ_TN_INFO_SENS"
#define UQ_TN_INFO_SENS_GPS     "UQ_TN_INFO_SENS_GPS"
#define UQ_TN_INFO_SENS_GPS_XYZ "UQ_TN_INFO_SENS_GPS_XYZ"
#define UQ_TN_SD                "UQ_TN_SD"
#define UQ_TN_SD_NID            "UQ_TN_SD_NID"
#define UQ_TN_SD_DEV_0          "UQ_TN_SD_DEV_0"
#define UQ_TN_SD_DEV_0_IMG      "UQ_TN_SD_DEV_0_IMG"
#define UQ_TN_SYS               "UQ_TN_SYS"
#define UQ_TN_SYS_NID           "UQ_TN_SYS_NID"
#define UQ_TN_SYS_BOOT          "UQ_TN_SYS_BOOT"
#define UQ_TN_SYS_BOOT_SWITCH   "UQ_TN_SYS_BOOT_SWITCH"
#define UQ_TN_SYS_BOOT_SWITCH   "UQ_TN_SYS_BOOT_ACTIVE"
#define UQ_TN_SYS_BOOT_SWITCH   "UQ_TN_SYS_BOOT_BACKUP"
#define UQ_TN_SYS_BOOT_SWITCH   "UQ_TN_SYS_BOOT_GOLDEN"
#define UQ_TN_SYS_BOOT_SWITCH   "UQ_TN_SYS_BOOT_NIB"

#define UQ_TAGNET_ADAPTER_LIST  "UQ_TAGNET_ADAPTER_LIST"

#endif          /* __TAGNET_H__ */
