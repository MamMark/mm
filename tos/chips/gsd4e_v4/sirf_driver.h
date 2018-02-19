/*
 * Copyright (c) 2008, 2010, 2017-2018 Eric B. Decker
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
 * Misc defines and constants for the sirf chipset.
 *
 * Internal definitions that the sirf (gsd4e) driver needs for various
 * control functions.
 */

#ifndef __SIRF_DRIVER_H__
#define __SIRF_DRIVER_H__

/* get external definitions */
#include <sirf_msg.h>

#ifdef notdef
/*
 * Boot up sequence commands:
 *
 * 1) Send SW ver
 * 2) poll clock status
 * 3) turn on MID 4 tracker data
 */

const uint8_t sirf_send_boot[] = {
  0xa0, 0xa2,
  0x00, 0x02,
  132,				// send sw ver (0x84)
  0x00,
  0x00, 0x84,
  0xb0, 0xb3,

  0xa0, 0xa2,
  0x00, 0x02,
  144,				// poll clock status (0x90)
  0x00,
  0x00, 0x90,
  0xb0, 0xb3,

  0xa0, 0xa2,			// turn on 4 (tracker data)
  0x00, 0x08,
  166,				// set message rate (0xa6)
  0,				// send now
  4,				// Tracker Data Out
  1,				// update rate
  0, 0, 0, 0,
  0x00, 0xab,
  0xb0, 0xb3,
};

/*
 * Message to send when turn on.
 *
 * 1) turn on MID 4 tracker data
 */

const uint8_t sirf_send_start[] = {
  0xa0, 0xa2,			// turn on 4 (tracker data)
  0x00, 0x08,
  166,				// set message rate (0xa6)
  0,				// send now
  4,				// Tracker Data Out
  1,				// update rate
  0, 0, 0, 0,
  0x00, 0xab,
  0xb0, 0xb3,
};
#endif notdef


const uint8_t nmea_4800[] = {
  '$', 'P', 'S', 'R', 'F',		// header
  '1', '0', '0', ',',			// set serial port MID
  '1', ',',				// protocol 0 SirfBinary, 1 - NEMA
  '4', '8', '0', '0', ',',		// baud rate
  '8', ',',				// 8 data bits
  '1', ',',				// 1 stop bit
  '0',					// no parity
  '*', '0', 'E',			// checksum
  '\r', '\n'				// terminator
};

const uint8_t nmea_9600[] = {
  '$', 'P', 'S', 'R', 'F',		// header
  '1', '0', '0', ',',			// set serial port MID
  '1', ',',				// protocol 0 SirfBinary, 1 - NEMA
  '9', '6', '0', '0', ',',		// baud rate
  '8', ',',				// 8 data bits
  '1', ',',				// 1 stop bit
  '0',					// no parity
  '*', '0', 'D',			// checksum
  '\r', '\n'				// terminator
};

const uint8_t nmea_57600[] = {
  '$', 'P', 'S', 'R', 'F',		// header
  '1', '0', '0', ',',			// set serial port MID
  '1', ',',				// protocol 0 SirfBinary, 1 - NEMA
  '5', '7', '6', '0', '0', ',',		// baud rate
  '8', ',',				// 8 data bits
  '1', ',',				// 1 stop bit
  '0',					// no parity
  '*', '3', '6',			// checksum
  '\r', '\n'				// terminator
};

const uint8_t nmea_115200[] = {
  '$', 'P', 'S', 'R', 'F',		// header
  '1', '0', '0', ',',			// set serial port MID
  '1', ',',				// protocol 0 SirfBinary, 1 - NEMA
  '1', '1', '5', '2', '0', '0', ',',	// baud rate
  '8', ',',				// 8 data bits
  '1', ',',				// 1 stop bit
  '0',					// no parity
  '*', '0', '5',			// checksum
  '\r', '\n'				// terminator
};

const uint8_t nmea_307200[] = {
  '$', 'P', 'S', 'R', 'F',		// header
  '1', '0', '0', ',',			// set serial port MID
  '1', ',',				// protocol 0 SirfBinary, 1 - NEMA
  '3', '0', '7', '2', '0', '0', ',', 	// baud rate
  '8', ',',				// 8 data bits
  '1', ',',				// 1 stop bit
  '0',					// no parity
  '*', '0', '4',			// checksum
  '\r', '\n'				// terminator
};

const uint8_t nmea_921600[] = {
  '$', 'P', 'S', 'R', 'F',		// header
  '1', '0', '0', ',',			// set serial port MID
  '1', ',',				// protocol 0 SirfBinary, 1 - NEMA
  '9', '2', '1', '6', '0', '0', ',', 	// baud rate
  '8', ',',				// 8 data bits
  '1', ',',				// 1 stop bit
  '0',					// no parity
  '*', '0', 'E',			// checksum
  '\r', '\n'				// terminator
};

const uint8_t nmea_1228800[] = {
  '$', 'P', 'S', 'R', 'F',		// header
  '1', '0', '0', ',',			// set serial port MID
  '1', ',',				// protocol 0 SirfBinary, 1 - NEMA
  '1', '2', '2', '8', '8', '0', '0', ',', // baud rate
  '8', ',',				// 8 data bits
  '1', ',',				// 1 stop bit
  '0',					// no parity
  '*', '3', '3',			// checksum
  '\r', '\n'				// terminator
};

const uint8_t nmea_sw_ver[] = {
  '$', 'P', 'S', 'R', 'F',		// header
  '1', '2', '5',        		// sw_ver MID
  '*', '2', '1',
  '\r', '\n'				// terminator
};

const uint8_t nmea_sirf_9600[] = {
  '$', 'P', 'S', 'R', 'F',		// header
  '1', '0', '0', ',',			// set serial port MID
  '0', ',',				// protocol 0 SirfBinary, 1 - NEMA
  '9', '6', '0', '0', ',',		// baud rate
  '8', ',',				// 8 data bits
  '1', ',',				// 1 stop bit
  '0',					// no parity
  '*', '0', 'C',			// checksum
  '\r', '\n'				// terminator
};

const uint8_t nmea_sirf_57600[] = {
  '$', 'P', 'S', 'R', 'F',		// header
  '1', '0', '0', ',',			// set serial port MID
  '0', ',',				// protocol 0 SirfBinary, 1 - NEMA
  '5', '7', '6', '0', '0', ',',		// baud rate
  '8', ',',				// 8 data bits
  '1', ',',				// 1 stop bit
  '0',					// no parity
  '*', '3', '7',			// checksum
  '\r', '\n'				// terminator
};

const uint8_t nmea_sirf_115200[] = {
  '$', 'P', 'S', 'R', 'F',		// header
  '1', '0', '0', ',',			// set serial port MID
  '0', ',',				// protocol 0 SirfBinary, 1 - NEMA
  '1', '1', '5', '2', '0', '0', ',',    // baud rate
  '8', ',',				// 8 data bits
  '1', ',',				// 1 stop bit
  '0',					// no parity
  '*', '0', '4',			// checksum
  '\r', '\n'				// terminator
};

const uint8_t nmea_sirf_307200[] = {
  '$', 'P', 'S', 'R', 'F',		// header
  '1', '0', '0', ',',			// set serial port MID
  '0', ',',				// protocol 0 SirfBinary, 1 - NEMA
  '3', '0', '7', '2', '0', '0', ',',    // baud rate
  '8', ',',				// 8 data bits
  '1', ',',				// 1 stop bit
  '0',					// no parity
  '*', '0', '5',			// checksum
  '\r', '\n'				// terminator
};

const uint8_t sirf_sw_ver[] = {
  0xa0, 0xa2,
  0x00, 0x02,
  132,				// send sw ver (0x84)
  0x00,
  0x00, 0x84,
  0xb0, 0xb3,
};

const uint8_t sirf_4800[] = {
  0xa0, 0xa2,
  0x00, 0x09,
  134,                          // set binary serial port, 0x86
  0x00, 0x00,
  0x12, 0xc0,                   // 4800
  0x08, 0x01,                   // 8 bits, 1 stop
  0x00, 0x00,                   // no parity, pad
  0x01, 0x61,
  0xb0, 0xb3,
};

const uint8_t sirf_9600[] = {
  0xa0, 0xa2,
  0x00, 0x09,
  134,                          // set binary serial port, 0x86
  0x00, 0x00,
  0x25, 0x80,                   // 9600
  0x08, 0x01,                   // 8 bits, 1 stop
  0x00, 0x00,                   // no parity, pad
  0x01, 0x34,
  0xb0, 0xb3,
};

const uint8_t sirf_57600[] = {
  0xa0, 0xa2,
  0x00, 0x09,
  134,                          // set binary serial port, 0x86
  0x00, 0x00,
  0xe1, 0x00,                   // 57600 (0x0000e100)
  0x08, 0x01,                   // 8 bits, 1 stop
  0x00, 0x00,                   // no parity, pad
  0x01, 0x70,
  0xb0, 0xb3,
};

const uint8_t sirf_115200[] = {
  0xa0, 0xa2,
  0x00, 0x09,
  134,                          // set binary serial port, 0x86
  0x00, 0x01,                   // 115200 (0x0001c200)
  0xc2, 0x00,
  0x08, 0x01,                   // 8 bits, 1 stop
  0x00, 0x00,                   // no parity, pad
  0x01, 0x52,
  0xb0, 0xb3,
};

const uint8_t sirf_307200[] = {
  0xa0, 0xa2,
  0x00, 0x09,
  134,                          // set binary serial port, 0x86
  0x00, 0x04,                   // 307200 (0x0004b000)
  0xb0, 0x00,
  0x08, 0x01,                   // 8 bits, 1 stop
  0x00, 0x00,                   // no parity, pad
  0x01, 0x43,
  0xb0, 0xb3,
};

const uint8_t sirf_921600[] = {
  0xa0, 0xa2,
  0x00, 0x09,
  134,                          // set binary serial port, 0x86
  0x00, 0x0e,                   // 921600 (0x000e1000)
  0x10, 0x00,
  0x08, 0x01,                   // 8 bits, 1 stop
  0x00, 0x00,                   // no parity, pad
  0x00, 0xad,
  0xb0, 0xb3,
};

const uint8_t sirf_1228800[] = {
  0xa0, 0xa2,
  0x00, 0x09,
  134,                          // set binary serial port, 0x86
  0x00, 0x12,                   // 1,228,800 (0x0012c000)
  0xc0, 0x00,
  0x08, 0x01,                   // 8 bits, 1 stop
  0x00, 0x00,                   // no parity, pad
  0x01, 0x61,
  0xb0, 0xb3,
};

const uint8_t sirf_peek_0[] = {
  0xa0, 0xa2,			// start seq
  0x00, 0x0c,			// length 12
  178, 3,			// peek/poke
  0,                            // type, peek
  4,                            // 4 bytes
  0, 0, 0, 0,                   // addr 0
  0, 0, 0, 0,                   // dummy data
  0x00, 0xb9,			// checksum
  0xb0, 0xb3			// end seq
};

const uint8_t sirf_full_pwr[] = {
  0xa0, 0xa2,			// start seq
  0x00, 0x02,			// length 2
  218, 0,			// Req Pwr Mode, Full Pwr
  0x00, 0xda,			// checksum
  0xb0, 0xb3			// end seq
};

const uint8_t sirf_go_mpm_0[] = {
  0xa0, 0xa2,			// start seq
  0x00, 0x06,			// length 6
  218, 2,			// Req Pwr Mode, MPM
  0,                            // time_out, 0 immediate MPM
  0,                            // control, RTC uncertainty, 250us (default)
  0, 0,                         // reserved
  0x00, 0xdc,			// checksum
  0xb0, 0xb3			// end seq
};

const uint8_t sirf_nmea_4800[] = {
  0xa0, 0xa2,			// start seq
  0x00, 0x18,			// len 24 (0x18)
  129,				// set nmea
  2,			        // mode, 0 enable nmea debug, 1 disable, 2 don't change.
  1, 1,				// GGA 1 sec period, checksum
  0, 1,				// GLL
  1, 1,	                        // GSA
  5, 1,				// GSV (5 sec period)
  1, 1,				// RMC
  0, 1,				// VTG
  0, 1,				// MSS
  0, 0,				// EPE
  0, 1,				// ZDA
  0, 0,				// Unused
  0x12, 0xc0,			// Baud rate (4800) (big endian)
  0x01, 0x65,			// checksum [0x01, 0x65]
  0xb0, 0xb3			// end seq
};


typedef struct {
  const uint32_t  speed;                // baud rate, bps
  const uint16_t  to_modifier;          // time out modifier
  const uint16_t  len;                  // len of config msg
  const uint8_t  *msg;                  // pointer to config msg
} gps_probe_entry_t;


/*
 * Instrumentation, Stats
 *
 * rx_errors: gets popped when either an rx_timeout, or any rx error,
 * rx_error includes FramingError, ParityError, and OverrunError.
 */
typedef struct {
  uint32_t starts;                    /* number of packets started */
  uint32_t complete;                  /* number completed successfully */
  uint16_t too_big;                   /* too large, aborted */
  uint16_t no_buffer;                 /* no buffer/msg available */
  uint16_t max_seen;                  /* max length seen */
  uint16_t chksum_fail;               /* bad checksum */
  uint16_t proto_fail;                /* proto abort */
  uint16_t rx_errors;                 /* rx_error, comm h/w not happy */
  uint16_t rx_timeouts;               /* number of rx timeouts */
  uint16_t resets;                    /* number of simple resets */
} sirfbin_stat_t;

#endif	/* __SIRF_DRIVER_H__ */
