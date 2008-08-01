/*
 * Copyright (c) 2008 Eric B. Decker
 * All rights reserved.
 *
 * Misc defines and constants for the sirf chipset.
 *
 * nmea_add_checksum and sirf_bin_add_checksum from gpsd/sirfmon.c 2.37
 */

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


uint8_t sirf_send_sw_ver_clock[] = {
  0xa0, 0xa2,			// start seq
  0x00, 0x02,			// len 2
  132,				// send sw ver
  0x00,				// unused
  0x00, 0x84,			// checksum
  0xb0, 0xb3,			// end seq
  0xa0, 0xa2,			// start seq
  0x00, 0x02,			// len 2
  144,				// send sw ver
  0x00,				// unused
  0x00, 0x90,			// checksum
  0xb0, 0xb3			// end seq
};


uint8_t sirf_poll_41[] = {
  0xa0, 0xa2,			// start sequence
  0x00, 0x08,			// length
  166,				// set message rate
  1,				// send now
  41,				// mid to be set
  0,				// update rate (turn off)
  0, 0, 0, 0,			// pad
  0x00, 0xd0,			// checksum
  0xb0, 0xb3			// end seq
};


#ifdef TEST_GPS_FUTZ

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


uint8_t sirf_combined[] = {
  0xa0, 0xa2,			// start sequence
  0x00, 0x08,			// length
  166,				// set message rate
  0,				// no poll
  41,				// mid to be set
  0,				// update rate (turn off)
  0, 0, 0, 0,			// pad
  0x00, 0xef,			// checksum
  0xb0, 0xb3,			// end seq
  0xa0, 0xa2,			// start sequence
  0x00, 0x08,			// length
  166,				// set message rate
  0,				// no poll
  2,				// mid to be set
  0,				// update rate (off)
  0, 0, 0, 0,			// pad
  0x00, 0xa9,			// checksum
  0xb0, 0xb3			// end seq
};

#endif
