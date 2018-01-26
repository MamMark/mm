/*
 * Copyright (c) 2015-2016, Eric B. Decker
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
 * Contact: Eric B. Decker <cire831@gmail.com>
 */

/**
 * Defining the platform-independently named packet structures to be the
 * chip-specific CC1000 packet structures.
 *
 * @author Eric B. Decker <cire831@gmail.com>
 */

#ifndef PLATFORM_MESSAGE_H
#define PLATFORM_MESSAGE_H

#include <Serial.h>
#include <Si446xRadio.h>
#include <Tagnet.h>

typedef union message_header {
  si446x_packet_header_t  header;
} message_header_t;

typedef union message_footer {
  si446x_packet_footer_t  footer;
} message_footer_t;

typedef struct message_metadata {
  union {
    si446x_metadata_t     si446x_meta;
  };

//  timestamp_metadata_t    ts_meta;

  flags_metadata_t        flags_meta;

  tagnet_name_meta_t      tn_name_meta;
  tagnet_payload_meta_t   tn_payload_meta;

} message_metadata_t;

#endif
