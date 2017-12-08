/**
 * Copyright (c) 2017 Daniel J. Maltbie
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
 * @author Daniel J. Maltbie (dmaltbie@daloma.org)
 *
 */

#ifndef __TAGNETADAPTER_H__
#define __TAGNETADAPTER_H__

#include <Tagnet.h>
#include <image_info.h>
#include <image_mgr.h>

/*
 * GPS Position and Time Information
 */
typedef struct {
  uint32_t                gps_x;
  uint32_t                gps_y;
  uint32_t                gps_z;
} tagnet_gps_xyz_t;

#define TN_GPS_XYZ_LEN (sizeof(tagnet_gps_xyz_t))

/*
 * System Execution Control & Status
 */
typedef struct {
  image_ver_t             ver_id;
  slot_state_t            state;
} tagnet_sys_exec_t;

#define TN_SYS_EXEC_LEN (sizeof(tagnet_sys_exec_t))

typedef struct {
  uint32_t             file;
  uint32_t             iota;
  uint32_t             count;
  uint8_t             *block;
//  tagnet_app_err_t     error;
  int32_t              error;
  uint16_t             delay;
} tagnet_dblk_bytes_t;

#define TN_DBLK_BYTES_LEN (sizeof(tagnet_dblk_bytes_t))

#endif   /* __TAGNETADAPTER_H__ */
