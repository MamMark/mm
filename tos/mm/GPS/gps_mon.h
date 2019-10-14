/*
 * Copyright (c) 2017-2019 Eric B. Decker
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
 * gps_mon.h: definitions for GPSmonitor state and commands.
 */

#ifndef __GPS_MON_H__
#define __GPS_MON_H__

#ifndef PACKED
#define PACKED __attribute__((__packed__))
#endif

typedef enum gps_debug_cmds {
  GDC_NOP           = 0,
  GDC_TURNON        = 1,
  GDC_TURNOFF       = 2,
  GDC_STANDBY       = 3,
  GDC_POWER_ON      = 4,
  GDC_POWER_OFF     = 5,
  GDC_CYCLE         = 6,
  GDC_STATE         = 7,
  GDC_MON_GO_HOME   = 8,
  GDC_MON_GO_NEAR   = 9,
  GDC_MON_GO_LOST   = 10,

  GDC_AWAKE_STATUS  = 0x10,
  GDC_MPM           = 0x11,
  GDC_PULSE         = 0x12,
  GDC_RESET         = 0x13,
  GDC_RAW_TX        = 0x14,
  GDC_HIBERNATE     = 0x15,
  GDC_WAKE          = 0x16,

  /*
   * canned messages are in the array canned_msgs
   * indexed by gp->data[0], 1st byte following the
   * cmd.
   */
  GDC_CANNED        = 0x80,

  GDC_SET_LOG_FLAG  = 0x81,
  GDC_CLR_LOG_FLAG  = 0x82,

  GDC_SET_LOGGING   = 0x83,
  GDC_CLR_LOGGING   = 0x84,

  GDC_FORCE_LOGGING = 0x85,
  GDC_GET_LOGGING   = 0x86,

  GDC_LOW           = 0xfc,
  GDC_SLEEP         = 0xfd,
  GDC_PANIC         = 0xfe,
  GDC_REBOOT        = 0xff,
} gps_cmd_t;


/*
 * gps_cmd packets come across TagNet and there are no alignment
 * constraints.  they simply are bytes.  Multibyte datums must be repacked
 * before used natively.
 */
typedef struct {
  uint8_t cmd;
} PACKED gps_simple_cmd_t;


typedef struct {
  uint8_t cmd;
  uint8_t data[];
} PACKED gps_raw_tx_t;


typedef enum mon_events {
  MON_EV_NONE           = 0,
  MON_EV_FAIL           = 1,
  MON_EV_BOOT           = 2,
  MON_EV_SWVER          = 3,
  MON_EV_STARTUP        = 4,
  MON_EV_MSG            = 5,
  MON_EV_OTS_NO         = 6,
  MON_EV_OTS_YES        = 7,
  MON_EV_FIX            = 8,
  MON_EV_TIME           = 9,
  MON_EV_LPM            = 10,
  MON_EV_LPM_ERROR      = 11,
  MON_EV_TIMEOUT_MINOR  = 12,
  MON_EV_TIMEOUT_MAJOR  = 13,
  MON_EV_MAJOR_CHANGED  = 14,
  MON_EV_CYCLE          = 15,
  MON_EV_STATE_CHK      = 16,
  MON_EV_PWR_OFF        = 17,
} mon_event_t;


typedef enum {
  GMS_OFF           = 0,                /* fresh boot */
  GMS_FAIL          = 1,                /* down, couldn't make it work */
  GMS_BOOTING       = 2,                /* letting driver communicate  */
  GMS_CONFIG        = 3,                /* config and inital swver */

  GMS_COMM_CHECK    = 4,                /* can we hear? */
  GMS_COLLECT       = 5,                /* gathering fixes */

  GMS_LPM_WAIT      = 6,                /* trying to go into LPM, low pwr  */
  GMS_LPM_RESTART   = 7,                /* lpm recovery, wait for shutdown */
  GMS_LPM           = 8,                /* in low power mode */

  GMS_STANDBY       = 9,                /* currently not used */
  GMS_MAX           = 9,

} gpsm_state_t;                         /* gps monitor minor state */


typedef enum {
  GMS_MAJOR_IDLE           = 0,         /* sleeping (LPM)          */
  GMS_MAJOR_CYCLE          = 1,         /* simple fix cycle        */
  GMS_MAJOR_LPM_COLLECT    = 2,         /* LPM Collection          */
  GMS_MAJOR_SATS_STARTUP   = 3,         /* SATS Startup, Collect   */
  GMS_MAJOR_SATS_COLLECT   = 4,         /* SATS Collection         */
  GMS_MAJOR_TIME_COLLECT   = 5,         /* TIME sync Collection    */
  GMS_MAJOR_FIX_DELAY      = 6,         /* CYCLE to IDLE delay after fix */
  GMS_MAJOR_MAX            = 6,
} gpsm_major_state_t;                   /* gps monitor major state */


#endif  /* __GPS_MON_H__ */
