/*
 * Copyright (c) 2008, 2010, 2012 Eric B. Decker
 * All rights reserved.
 *
 * Misc defines and constants for the sirf chipset.
 * Updated for SirfStarIV (org4472).
 */

#ifndef __SIRF_H__
#define __SIRF_H__

#define SIRF_SPI_IDLE	 0xa7
#define SIRF_SPI_IDLE_2	 0xb4

#define SIRF_BIN_START   0xa0
#define SIRF_BIN_START_2 0xa2
#define SIRF_BIN_END     0xb0
#define SIRF_BIN_END_2   0xb3

/*
 * DT -> Data, Typed (should have been TD for Typed Data
 * but at this point, probably more trouble than it is worth
 * to change it.
 *
 * GPS_BUF_SIZE is biggest packet (MID 41, 188 bytes observed),
 *   SirfBin overhead (start, len, chksum, end) 8 bytes
 *   DT overhead (8 bytes).   204 rounded up to 256.
 *   GPS buffers are used to collect gps message packets and
 *   get passed to the msg processor (collector).
 *
 * The ORG4472 driver uses SPI which is master/slave.  Access is
 * direct and no interrupts are used.  All accesses are done from
 * syncronous level.
 *
 * GPS_START_OFFSET: offset into the msg buffer where the incoming bytes
 *   should be put.  Skips over DT overhead.
 *
 * GPS_OVERHEAD: space in msg buffer for overhead bytes.  Sum of DT overhead
 * and osp packet header and trailer.  16 bytes total.
 *
 * BUF_INCOMING_SIZE is the size of the chunk used by the lowest
 * layer to snarf SPI blocks.  It is the minimum number of bytes we
 * snarf from the gps via the spi.
 */

#define GPS_BUF_SIZE		256
#define GPS_START_OFFSET	8
#define SIRF_OVERHEAD		8
#define GPS_OVERHEAD		16
#define BUF_INCOMING_SIZE	32

#define MID_NAVDATA	   2
#define NAVDATA_LEN	   41

#define MID_CLOCKSTATUS	   7
#define CLOCKSTATUS_LEN	   20

#define MID_GEODETIC	   41
#define GEODETIC_LEN	   91

/*
 * idle block.   (size same as BUF_INCOMING_SIZE)
 */
const uint8_t osp_idle_block[] = {
  0xa7, 0xb4, 0xa7, 0xb4, 0xa7, 0xb4, 0xa7, 0xb4,
  0xa7, 0xb4, 0xa7, 0xb4, 0xa7, 0xb4, 0xa7, 0xb4,
  0xa7, 0xb4, 0xa7, 0xb4, 0xa7, 0xb4, 0xa7, 0xb4,
  0xa7, 0xb4, 0xa7, 0xb4, 0xa7, 0xb4, 0xa7, 0xb4,
};

/*
 * nmea_go_sirf_bin: tell the gps in nmea mode to go into sirf binary.
 * checksum for 115200 is 04, 57600 is 37
 *
 * note: baud doesn't really matter.  We are using the org4472 in
 * SPI mode.
 *
 * output means we send it to the chip.   input comes from the chip.
 * ie.  relative to the host (us, main cpu).
 */

const uint8_t nmea_go_sirf_bin[] = {	// output
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


const uint8_t nmea_oktosend[] = {	// input
  '$', 'P', 'S', 'R', 'F',		// header
  '1', '5', '0', ',',			// OkToSend
  '1',					// 1 - says yep
  '*', '3', 'E',			// checksum
  '\r', '\n'				// terminator
};


const uint8_t nmea_shutdown[] = {	// output
  '$', 'P', 'S', 'R', 'F',		// header
  '1', '1', '7', ',',			// set control MID
  '1', '6', ',',			// sub id, shutdown
  '*', '0', 'B',			// checksum
  '\r', '\n'				// terminator
};


const uint8_t osp_oktosend[] = {	// input
  0xa0, 0xa2,
  0x00, 0x02,
  18,
  1,
  0x00, 0x13,
  0xb0, 0xb3,
};


const uint8_t osp_shutdown[] = {	// output
  0xa0, 0xa2,
  0x00, 0x02,
  0xCD,					// 205
  0x10,					// 16
  0x00, 0xdd,
  0xb0, 0xb3,
};


const uint8_t osp_pwr_mode[] = {	// input
  0xa0, 0xa2,
  0x00, 0x02,
  0xE9, 0x0B,				// 233, 11
  0x00, 0xf4,
  0xb0, 0xb3,
};


const uint8_t osp_send_sw_ver[] = {	// output
  0xa0, 0xa2,
  0x00, 0x02,
  132,					// send sw ver (0x84)
  0x00,
  0x00, 0x84,
  0xb0, 0xb3,
};


const uint8_t osp_revision_req[] = {	// output
  0xa0, 0xa2,
  0x00, 0x02,
  212,
  0x07,
  0x00, 0xdb,
  0xb0, 0xb3,
};


const uint8_t osp_poll_clock[] = {	// output
  0xa0, 0xa2,
  0x00, 0x02,
  144,					// poll clock status (0x90)
  0x00,
  0x00, 0x90,
  0xb0, 0xb3,
};


const uint8_t osp_poll_nav[] = {	// output
  0xa0, 0xa2,
  0x00, 0x02,
  152,					// poll nav (0x98)
  0x00,
  0x00, 0x98,
  0xb0, 0xb3,
};


const uint8_t osp_message_rate_msg[] = { // output
  0xa0, 0xa2,
  0x00, 0x08,
  166,					// A6
  2,					// enable/disable all
  0,
  0,
  0, 0, 0, 0,
  0x00, 0xa8,
  0xb0, 0xb3,
};


const uint8_t osp_send_tracker[] = {	// output
  0xa0, 0xa2,				// turn on 4 (tracker data)
  0x00, 0x08,
  166,					// set message rate (0xa6)
  0,					// send now
  4,					// Tracker Data Out
  1,					// update rate
  0, 0, 0, 0,
  0x00, 0xab,
  0xb0, 0xb3,
};


#ifdef GPS_TEST_FUTZ

const uint8_t sirf_go_nmea[] = {// output 
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
