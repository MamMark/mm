/*
 * Copyright (c) 2008, 2010 Eric B. Decker
 * All rights reserved.
 *
 * Misc defines and constants for the sirf chipset.
 */

#ifndef __SIRF_H__
#define __SIRF_H__

#define SIRF_BIN_START   0xa0
#define SIRF_BIN_START_2 0xa2
#define SIRF_BIN_END     0xb0
#define SIRF_BIN_END_2   0xb3

/*
 * BUF_SIZE is biggest packet (MID 41, 188 bytes observed),
 *   SirfBin overhead (start, len, chksum, end) 8 bytes
 *   DT overhead (8 bytes).   204 rounded up to 256.
 *
 * GPS_OVR_SIZE: size of overflow buffer.  Space for bytes coming
 *   in on interrupts while we are processing the previous msg.
 *
 * GPS_START_OFFSET: offset into the msg buffer where the incoming bytes
 *   should be put.  Skips over DT overhead.
 *
 * GPS_OVERHEAD: space in msg buffer for overhead bytes.
 */

#define GPS_BUF_SIZE	  256
#define GPS_OVR_SIZE	   32
#define GPS_START_OFFSET    8
#define SIRF_OVERHEAD       8
#define GPS_OVERHEAD	   16

#define MID_NAVDATA	   2
#define NAVDATA_LEN	   41
#define MID_CLOCKSTATUS	   7
#define CLOCKSTATUS_LEN	   20
#define MID_GEODETIC	   41
#define GEODETIC_LEN	   91

/*
 * nmea_go_sirf_bin: tell the gps in nmea mode to go into sirf binary.
 * checksum for 115200 is 04, 57600 is 37
 */

uint8_t nmea_go_sirf_bin[] = {
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


#ifdef GPS_TEST_FUTZ

uint8_t sirf_go_nmea[] = {
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
  0x01, 0x65,			// checksum
  0xb0, 0xb3			// end seq
};

#endif

#endif	/* __SIRF_H__ */
