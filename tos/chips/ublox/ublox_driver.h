/*
 * Copyright (c) 2020 Eric B. Decker
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
 *
 * Misc defines and constants for ublox chipsets.
 *
 * Internal definitions that the ublox gps driver needs for various
 * control functions.
 */

#ifndef __UBLOX_DRIVER_H__
#define __UBLOX_DRIVER_H__

/* get external definitions */
#include <ublox_msg.h>

/*
 * Instrumentation, Stats
 *
 * rx_errors: gets popped when either an rx_timeout, or any rx error,
 * rx_error includes FramingError, ParityError, and OverrunError.
 *
 * majority of instrumentation stats are defined by the
 * dt_gps_proto_stats_t structure in typed_data.h.
 */

typedef struct {
  uint16_t no_buffer;                 /* no buffer/msg available */
  uint16_t max_seen;                  /* max legal seen */
  uint16_t largest_seen;              /* largest packet length seen */
} ubx_other_stats_t;

#endif  /* __UBLOX_DRIVER_H__ */
