/*
 * Copyright (c) 2017-2018 Eric B. Decker
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

/*
 * gps_cmd.h: definitions for remote gps commands.
 * debugging
 */

#ifndef __GPS_CMD_H__
#define __GPS_CMD_H__

#ifndef PACKED
#define PACKED __attribute__((__packed__))
#endif

typedef enum gps_debug_cmds {
  GDC_NOP           = 0,
  GDC_TURNON        = 1,
  GDC_TURNOFF       = 2,
  GDC_STANDBY       = 3,
  GDC_HIBERNATE     = 4,
  GDC_WAKE          = 5,
  GDC_PULSE_ON_OFF  = 6,
  GDC_AWAKE_STATUS  = 7,
  GDC_RESET         = 8,
  GDC_POWER_ON      = 9,
  GDC_POWER_OFF     = 10,
  GDC_SEND_MPM      = 11,
  GDC_SEND_FULL     = 12,
  GDC_RAW_TX        = 13,
  GDC_REBOOT        = 14,
  GDC_PANIC         = 15,
} gps_cmd_t;


/*
 * gps_cmd packets come across TagNet and there
 * are no alignment constraints.  they simply are
 * bytes.  Multibyte datums must be repacked before
 * used as such.
 */
typedef struct {
  uint8_t cmd;
} PACKED gps_simple_cmd_t;


typedef struct {
  uint8_t cmd;
  uint8_t  data[];
} PACKED gps_raw_tx_t;

#endif  /* __GPS_CMD_H__ */
