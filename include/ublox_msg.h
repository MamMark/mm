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
 */

#ifndef __UBLOX_MSG_H__
#define __UBLOX_MSG_H__

/*
 * Various external Ublox UBX structures and definitions that are protocol
 * dependent.
 */

#ifndef PACKED
#define PACKED __attribute__((__packed__))
#endif

#define NMEA_START      '$'
#define NMEA_END        '*'

#define UBX_SYNC1       0xB5
#define UBX_SYNC2       0x62

/* Packet Format:
 *
 *     1       1       1      1        2       LEN        2
 * +-------+-------+-------+------+--------+---------+---------+
 * | SYNC1 | SYNC2 | CLASS |  ID  |   LEN  | PAYLOAD | CHK_A/B |
 * +-------+-------+-------+------+--------+---------+---------+
 */

#define UBX_CLASS(msg)          (msg[2])
#define UBX_ID(msg)             (msg[3])
#define UBX_CLASS_ID(msg)       (UBX_CLASS(msg) << 8 | UBX_ID(msg))

/* overhead: sync (2), class (1), id (1), len (2), chk_a/chk_b (2) */
#define UBX_OVERHEAD    8


/*
 * max size (UBX length) message we will receive
 *
 * If we are eavesdropping then we want to see everything
 */
#define UBX_MIN_MSG     0
#define UBX_MAX_MSG     512


typedef struct {
  uint8_t   sync1;
  uint8_t   sync2;
  uint8_t   class;
  uint8_t   id;
  uint16_t  len;
  uint8_t   data[0];
} PACKED ubx_header_t;


/*
 * UBX class identifiers
 * See page 145 of u-blox 8 / u-blox M8 Receiver description - Manual
 *     R18 (9c8fe58), 24 March 2020
 */
typedef enum {
  UBX_CLASS_NAV     = 0x01,     // Navigation Results Messages
  UBX_CLASS_RXM     = 0x02,     // Receiver Manager Messages
  UBX_CLASS_INF     = 0x04,     // Information Messages
  UBX_CLASS_ACK     = 0x05,     // Ack/Nak Messages
  UBX_CLASS_CFG     = 0x06,     // Configuration Input Messages
  UBX_CLASS_UPD     = 0x09,     // Firmware Update Messages
  UBX_CLASS_MON     = 0x0A,     // Monitoring Messages
  UBX_CLASS_AID     = 0x0B,     // AssistNow Aiding Messages
  UBX_CLASS_TIM     = 0x0D,     // Timing Messages
  UBX_CLASS_ESF     = 0x10,     // External Sensor Fusion Messages
  UBX_CLASS_MGA     = 0x13,     // Multiple GNSS Assistance Messages
  UBX_CLASS_LOG     = 0x21,     // Logging Messages
  UBX_CLASS_SEC     = 0x27,     // Security Feature Messages
  UBX_CLASS_HNR     = 0x28,     // High Rate Navigation
  UBX_CLASS_NMEA    = 0xF0,     // NMEA Strings
} ubx_classes_t;


/* UBX_CLASS_NAV (01) */
enum {
  UBX_NAV_POSECEF   = 0x01,     // Position Solution in ECEF
  UBX_NAV_POSLLH    = 0x02,     // Geodetic Position Solution
  UBX_NAV_STATUS    = 0x03,     // Receiver Navigation Status
  UBX_NAV_DOP       = 0x04,     // Dilution of precision
  UBX_NAV_PVT       = 0x07,     // Position, Velocity, Time, (and more).
  UBX_NAV_ODO       = 0x09,     // Odometer Solution
  UBX_NAV_RESETODO  = 0x10,     // Reset odometer
  UBX_NAV_VELECEF   = 0x11,     // Velocity Solution in ECEF
  UBX_NAV_VELNED    = 0x12,     // Velocity Solution in NED
  UBX_NAV_HPPOSECEF = 0x13,     // ECEF (High Precision)
  UBX_NAV_HPPOSLLH  = 0x14,     // Geo (High Precision)
  UBX_NAV_TIMEGPS   = 0x20,     // GPS Time Solution
  UBX_NAV_TIMEUTC   = 0x21,     // UTC Time Solution
  UBX_NAV_CLOCK     = 0x22,     // Clock Solution
  UBX_NAV_TIMEGLO   = 0x23,     // GLO Time Solution
  UBX_NAV_TIMEBDS   = 0x24,     // BDS Time Solution
  UBX_NAV_TIMEGAL   = 0x25,     // Galileo Time Solution
  UBX_NAV_TIMELS    = 0x26,     // Leap second event information
  UBX_NAV_ORB       = 0x34,     // GNSS Orbit Database Info
  UBX_NAV_SAT       = 0x35,     // Satellite Information
  UBX_NAV_GEOFENCE  = 0x39,     // Geofencing status.
  UBX_NAV_SVIN      = 0x3B,     // Survey-in data.  Survey In status.
  UBX_NAV_RELPOSNED = 0x3C,     // Relative Positioning (NED)
  UBX_NAV_SIG       = 0x43,     // Signal Information
  UBX_NAV_AOPSTATUS = 0x60,     // Auton. Orbit Parameters Status
  UBX_NAV_EOE       = 0x61,     // End of Epoch
};



/* UBX_CLASS_INF (04) */
enum {
  UBX_INF_ERROR     = 0x00,     // ASCII output with error contents
  UBX_INF_WARNING   = 0x01,     // ASCII output with warning contents
  UBX_INF_NOTICE    = 0x02,     // ASCII output with informational contents
  UBX_INF_TEST      = 0x03,     // ASCII output with test contents
  UBX_INF_DEBUG     = 0x04,     // ASCII output with debug contents
};


/* UBX_CLASS_ACK (05) */
enum {
  UBX_ACK_NACK      = 0x00,
  UBX_ACK_ACK       = 0x01,
  UBX_ACK_NONE      = 0x02,     //  Not a real value
};

typedef struct {
  uint8_t   sync1;
  uint8_t   sync2;
  uint8_t   class;
  uint8_t   id;
  uint16_t  len;
  uint8_t   ackClass;
  uint8_t   ackId;
  uint8_t   chkA;
  uint8_t   chkB;
} PACKED ubx_ack_t;


/* UBX_CLASS_CFG (06) */
enum {
  UBX_CFG_PRT       = 0x00,     // Port control
  UBX_CFG_MSG       = 0x01,     // Message Poll/Configuration, msg rate.
  UBX_CFG_INF       = 0x02,     // Information, poll or information
  UBX_CFG_RST       = 0x04,     // Reset Receiver
  UBX_CFG_DAT       = 0x06,     // Set/Get User-defined Datum
  UBX_CFG_RATE      = 0x08,     // Nav/Meas Rate Settings. (port baud rates).
  UBX_CFG_CFG       = 0x09,     // Configuration control.
  UBX_CFG_RXM       = 0x11,     // RXM configuration
  UBX_CFG_ANT       = 0x13,     // Antenna Control Settings
  UBX_CFG_SBAS      = 0x16,     // SBAS configuration
  UBX_CFG_NMEA      = 0x17,     // Extended NMEA config V1
  UBX_CFG_USB       = 0x1B,     // USB Configuration
  UBX_CFG_ODO       = 0x1E,     // Odometer
  UBX_CFG_NAVX5     = 0x23,     // Navigation Engine Expert Settings
  UBX_CFG_NAV5      = 0x24,     // Navigation Engine Settings.
  UBX_CFG_TP5       = 0x31,     // Time Pulse Parameters
  UBX_CFG_RINV      = 0x34,     // Remote Inventory
  UBX_CFG_ITFM      = 0x39,     // Jamming/Interference Monitor config.
  UBX_CFG_PM2       = 0x3B,     // Extended power management configuration
  UBX_CFG_GNSS      = 0x3E,     // GNSS system configuration
  UBX_CFG_LOGFILTER = 0x47,     // Data Logger Configuration
  UBX_CFG_PWR       = 0x57,     // Pwr control.
  UBX_CFG_GEOFENCE  = 0x69,     // Geofencing configuration
  UBX_CFG_DGNSS     = 0x70,     // DGNSS configuration
  UBX_CFG_TMODE3    = 0x71,     // Time Mode Settings 3.  (Survey In Mode)
  UBX_CFG_PMS       = 0x86,     // Power mode setup
  UBX_CFG_VALDEL    = 0x8C,     // v27 key/val delete
  UBX_CFG_VALSET    = 0x8A,     // v27 key/val set config
  UBX_CFG_VALGET    = 0x8B,     // v27 key/val get config
  UBX_CFG_BATCH     = 0x93,     // Get/set data batching configuration.
};


/* used by UBX_CLASS_CFG/UBX_CFG_PRT */
enum {
  UBX_COM_PORT_I2C  = 0,
  UBX_COM_PORT_UART1= 1,
  UBX_COM_PORT_UART2= 2,
  UBX_COM_PORT_USB  = 3,
  UBX_COM_PORT_SPI  = 4,

  UBX_COM_TYPE_UBX  = (1 << 0),
  UBX_COM_TYPE_NMEA = (1 << 1),
  UBX_COM_TYPE_RTCM3= (1 << 5),
};


typedef struct {
  uint8_t   sync1;
  uint8_t   sync2;
  uint8_t   class;
  uint8_t   id;
  uint16_t  len;
  uint8_t   portId;
  uint8_t   reserved1;
  uint16_t  txReady;
  uint32_t  mode;
  uint32_t  baudRate;
  uint16_t  inProtoMask;
  uint16_t  outProtoMask;
  uint16_t  flags;
  uint8_t   reserved2[2];
  uint8_t   chkA;
  uint8_t   chkB;
} PACKED ubx_cfg_prt_t;


/* UBX_CLASS_MON (0A) */
enum {
  UBX_MON_IO        = 0x02,     // I/O Subsystem Status
  UBX_MON_VER       = 0x04,     // Software Version.
  UBX_MON_MSGPP     = 0x06,     // Message Parse and Process Status
  UBX_MON_RXBUF     = 0x07,     // Rx Buffer Status
  UBX_MON_TXBUF     = 0x08,     // Tx Buffer Status.  tx buffer size/state.
  UBX_MON_HW        = 0x09,     // Hardware Status
  UBX_MON_HW2       = 0x0B,     // Extended Hardware Status
  UBX_MON_RXR       = 0x21,     // Receiver Status Information
  UBX_MON_PATCH     = 0x27,     // Patches
  UBX_MON_GNSS      = 0x28,     // major GNSS selections
  UBX_MON_COMMS     = 0x36,     // Comm port information
  UBX_MON_HW3       = 0x37,     // HW I/O pin information
  UBX_MON_RF        = 0x38,     // RF information
};


/* UBX_CLASS_TIM (0D) */
enum {
  UBX_TIM_TP        = 0x01,     // Time Pulse Timedata
  UBX_TIM_TM2       = 0x03,     // Time mark data
  UBX_TIM_VRFY      = 0x06,     // Sourced Time Verification
};


/* UBX_CLASS_LOG (21) */
enum {
  UBX_LOG_ERASE            = 0x03,  // Erase Logged Data
  UBX_LOG_STRING           = 0x04,  // Log arbitrary string
  UBX_LOG_CREATE           = 0x07,  // Create Log File
  UBX_LOG_INFO             = 0x08,  // Poll for log information
  UBX_LOG_RETRIEVE         = 0x09,  // Request log data
  UBX_LOG_RETRIEVEPOS      = 0x0B,  // Position fix log entry
  UBX_LOG_RETRIEVESTRING   = 0x0D,  // Byte string log entry
  UBX_LOG_FINDTIME         = 0x0E,  // Find index of a log entry
  UBX_LOG_RETRIEVEPOSEXTRA = 0x0F,  // Odometer log entry
};


/* UBX_CLASS_SEC (27) */
enum {
  UBX_SEC_UNIQID    = 0x03,     // Unique chip ID
};


#endif  /* __UBLOX_MSG_H__ */
