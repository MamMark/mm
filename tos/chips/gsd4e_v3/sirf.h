/*
 * Copyright (c) 2008, 2010 Eric B. Decker
 * All rights reserved.
 *
 * Misc defines and constants for the sirf chipset.
 */

#ifndef __SIRF_H__
#define __SIRF_H__

#define NMEA_START       '$'
#define NMEA_END         '*'

#define SIRF_BIN_A0      0xa0
#define SIRF_BIN_A2      0xa2

#define SIRF_BIN_B0      0xb0
#define SIRF_BIN_B3      0xb3

/* overhead: start (2), len (2), checksum (2), end (2) */
#define SIRF_OVERHEAD       8

#define MID_NAVDATA	   2
#define NAVDATA_LEN	   41
#define MID_CLOCKSTATUS	   7
#define CLOCKSTATUS_LEN	   20
#define MID_GEODETIC	   41
#define GEODETIC_LEN	   91

#ifdef notdef
/*
 * Boot up sequence commands:
 *
 * 1) Send SW ver
 * 2) poll clock status
 * 3) turn on MID 4 tracker data
 */

uint8_t sirf_send_boot[] = {
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

uint8_t sirf_send_start[] = {
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


uint8_t nmea_set_9600[] = {
  '$', 'P', 'S', 'R', 'F',		// header
  '1', '0', '0', ',',			// set serial port MID
  '1', ',',				// protocol 0 SirfBinary, 1 - NEMA
  '9', '6', '0', '0', ',',		// baud rate
  '8', ',',				// 8 data bits
  '1', ',',				// 1 stop bit
  '0',					// no parity
  '*', '3', '7',			// checksum  ['0','D']
  '\r', '\n'				// terminator
};

uint8_t nmea_set_sirf_9600[] = {
  '$', 'P', 'S', 'R', 'F',		// header
  '1', '0', '0', ',',			// set serial port MID
  '0', ',',				// protocol 0 SirfBinary, 1 - NEMA
  '9', '6', '0', '0', ',',		// baud rate
  '8', ',',				// 8 data bits
  '1', ',',				// 1 stop bit
  '0',					// no parity
  '*', '3', '7',			// checksum  ['0','C']
  '\r', '\n'				// terminator
};

uint8_t nmea_set_57600[] = {
  '$', 'P', 'S', 'R', 'F',		// header
  '1', '0', '0', ',',			// set serial port MID
  '1', ',',				// protocol 0 SirfBinary, 1 - NEMA
  '5', '7', '6', '0', '0', ',',		// baud rate
  '8', ',',				// 8 data bits
  '1', ',',				// 1 stop bit
  '0',					// no parity
  '*', '3', '7',			// checksum  ['3','6']
  '\r', '\n'				// terminator
};

uint8_t nmea_set_sirf_57600[] = {
  '$', 'P', 'S', 'R', 'F',		// header
  '1', '0', '0', ',',			// set serial port MID
  '0', ',',				// protocol 0 SirfBinary, 1 - NEMA
  '5', '7', '6', '0', '0', ',',		// baud rate
  '8', ',',				// 8 data bits
  '1', ',',				// 1 stop bit
  '0',					// no parity
  '*', '3', '7',			// checksum  ['3','7']
  '\r', '\n'				// terminator
};

uint8_t sirf_ver[] = {
  0xa0, 0xa2,
  0x00, 0x02,
  132,				// send sw ver (0x84)
  0x00,
  0x00, 0x84,
  0xb0, 0xb3,
};

uint8_t sirf_set_9600[] = {
  0xa0, 0xa2,
  0x00, 0x09,
  134,
  0x00, 0x00,
  0x25, 0x80,
  0x08, 0x01,
  0x00, 0x00,
  0x01, 0x34,
  0xb0, 0xb3,
};

uint8_t sirf_set_nmea[] = {
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
  0, 0,				// Unused
  0, 1,				// ZDA
  0, 0,				// Unused
  0x12, 0xc0,			// Baud rate (4800) (big endian)
  0x01, 0x65,			// checksum [0x01, 0x65]
  0xb0, 0xb3			// end seq
};


/*
 * used to control what parameters setting to try when checking
 * gps operational state.
 */
typedef struct {
  uint8_t        mode;   // 0 = SIRF Binary, 1 = NMEA
  uint32_t       speed;
  uint32_t       len;
  uint8_t        *msg;
} gps_check_option_t;


#endif	/* __SIRF_H__ */
