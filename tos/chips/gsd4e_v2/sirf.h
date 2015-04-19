/*
 * Copyright (c) 2008, 2010, 2012, 2014, 2015 Eric B. Decker
 * All rights reserved.
 *
 * looks like the next time this code will be worked on is 2016
 *
 * Misc defines and constants for the sirf chipset.
 * Updated for SirfStarIV (org4472).   Further updated Feb 2014
 * for Antenova M10478 (yet another GSD4e chipset).
 *
 * Feb 16, 2014, Antenova M10478 prototype contains version:
 *
 *     GSD4e_4.1.2-P1 R+ 11/15/2011 319-Nov 15 2011-23:04:55.GSD4e..2..
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
 * to change it).
 *
 * GPS_BUF_SIZE is biggest packet (MID 41, 188 bytes observed),
 *   SirfBin overhead (start, len, chksum, end) 8 bytes
 *   DT overhead (8 bytes).   204 rounded up to 256.
 *   GPS buffers are used to collect gps message packets and
 *   get passed to the msg processor (collector).
 *
 * The ORG4472/M10478 driver uses SPI which is master/slave.  Access is
 * direct and no interrupts are used.  All accesses are done from
 * syncronous (task) level.
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


#ifdef notdef
const uint8_t nmea_shutdown[] = {	// input
  '$', 'P', 'S', 'R', 'F',		// header
  '1', '1', '7', ',',			// set control MID
  '1', '6', ',',			// sub id, shutdown
  '*', '0', 'B',			// checksum
  '\r', '\n'				// terminator
};
#endif


/*
 * OSP messages.
 *
 * directions are relative to the GSD4e chip.   This is the same as the CSR plc
 * (Sirf) documentation.
 *
 * issue 9, 13, 15 refer to GSD4e OSP Manual (CS-129291-DC-<issue>.  The post CSR
 * acquisition of Sirf.
 *
 * An earlier Sirf document is refered to as 2.4 ((c) 2008).
 *
 * all -> Issue 9, 13, 15, and 2.4
 */

/*
 * Ack/Nack/Error structure
 *
 * SSB ACK  MID 11
 * SSB NACK MID 12
 *
 * 2 byte payload, MID, and {N,}ACK_ID
 */

typedef struct gsd4e_msg_ack75 {
  uint8_t mid;                          // 0x4b (75)
  uint8_t sid;                          // 1
  uint8_t echo_mid;                     // what msg being ack'd
  uint8_t echo_sid;                     // what msg sid
  uint8_t ack_nack;                     // ack/nack/error code
  uint8_t reserved[2];                  // pad
} gsd4e_msg_ack_t;


enum {
  GSD4E_ACK_ACK         = 0,            /* ack */
  GSD4E_ACK_UNK         = 0xfa,         /* not recognized */
  GSD4E_ACK_BAD_PARAMS  = 0xfb,         /* param not understood */
  GSD4E_ACK_BAD_REV     = 0xfc,         /* revision not supported */
  GSD4E_ACK_BAD_NAV     = 0xfd,         /* nav bit aiding not supported */
  GSD4E_ACK_BAD_EPHEM   = 0xfe,         /* ephem status not accepted */
  GSD4E_ACK_NACK        = 0xff,         /* nack */
};


typedef struct gsd4e_msg_reject75 {
  uint8_t mid;                          // 0x4b (75)
  uint8_t sid;                          // 2
  uint8_t rej_mid;                      // what msg being ack'd
  uint8_t rej_sid;                      // what msg sid
  uint8_t rej_reason;                   // bit mask
} gsd4e_msg_reject_t;


enum {
  GSD4E_REJECT_RESERVED         = 0x01,
  GSD4E_REJECT_NOT_READY        = 0x02,
  GSD4E_REJECT_NOT_AVAILABLE    = 0x04,
  GSD4E_REJECT_BAD_FORMAT       = 0x08,
  GSD4E_REJECT_NO_TIME_PULSE    = 0x10,
  GSD4E_REJECT_UNUSED           = 0x20,
  /* bits 7,8 reserved */
};
  


const uint8_t osp_oktosend[] = {	// output
  0xa0, 0xa2,                           // all
  0x00, 0x02,
  0x12,                                 // 18
  0x01,
  0x00, 0x13,
  0xb0, 0xb3,
};


const uint8_t osp_hw_req[] = {          // output
  0xa0, 0xa2,                           // all
  0x00, 0x02,
  0x47,                                 // 71
  0x00, 0x47,
  0xb0, 0xb3,
};


const uint8_t osp_hw_resp[] = {         // input
  0xa0, 0xa2,                           // all
  0x00, 0x08,
  0xd6,					// 214
  0x20,                                 // hw_config
  0x00, 0x00, 0x00, 0x00, 0x00,         // nominal freq
  0x00,                                 // nw_enhance_type
  0x00, 0xf6,                           // checksum
  0xb0, 0xb3,                           // term
};


const uint8_t osp_factory_reset[] = {   // input
  0xa0, 0xa2,
  0x00, 0x19,
  0x80,                                 // 128
  0, 0, 0, 0,                           // X
  0, 0, 0, 0,                           // Y
  0, 0, 0, 0,                           // Z
  0, 0, 0, 0,                           // clock drift
  0, 0, 0, 0,                           // TOW
  0, 0,                                 // week (extended)
  12,                                   // channels
  0x88,                                 // factory start,
                                        // System reset (actually, noop)
  0x01, 0x14,
  0xb0, 0xb3,
};


const uint8_t osp_shutdown[] = {	// input
  0xa0, 0xa2,                           // all
  0x00, 0x02,
  0xcd,					// 205
  0x10,					// 16
  0x00, 0xdd,
  0xb0, 0xb3,
};


/*
 * send (132, 0), response (6)
 */
const uint8_t osp_send_sw_ver[] = {	// input
  0xa0, 0xa2,                           // all
  0x00, 0x02,
  0x84,					// 132, send sw ver (0x84)
  0x00,
  0x00, 0x84,
  0xb0, 0xb3,
};


/*
 * send (144), get (7) back
 */
const uint8_t osp_poll_clock[] = {	// input
  0xa0, 0xa2,                           // all
  0x00, 0x02,
  0x90,					// 144 poll clock status
  0x00,
  0x00, 0x90,
  0xb0, 0xb3,
};


/*
 * send (152, 0), get (19) back
 */
const uint8_t osp_poll_nav[] = {	// input
  0xa0, 0xa2,                           // all
  0x00, 0x02,
  0x98,                                 // 152
  0x00,                                 // reserved
  0x00, 0x98,
  0xb0, 0xb3,
};


/*
 * osp_set_message_rate (166)
 *
 * mode: 0 - enable/disable one message
 *       1 - poll one message instantly ????
 *       2 - enable/disable all messages
 *       3 - enable/disable nav msgs (2, 4)
 *       4 - enable/disable debug (9, 255)
 *       5 - enable disable nav debug (7, 28-31)
 */
const uint8_t osp_message_rate_msg[] = { // input
  0xa0, 0xa2,                            // all
  0x00, 0x08,
  0xa6,					 // 166
  2,					 // mode: enable/disable all
  0,                                     // mid
  0,                                     // update rate (0-30)
  0, 0, 0, 0,                            // reserved
  0x00, 0xa8,
  0xb0, 0xb3,
};


const uint8_t osp_enable_tracker[] = {	// input
  0xa0, 0xa2,				// all
  0x00, 0x08,                           // turn on 4 (tracker data)
  0xa6,					// 166 set message rate
  0,					// enable/disable one message
  4,					// Tracker Data Out
  1,					// update rate (once/sec)
  0, 0, 0, 0,
  0x00, 0xab,
  0xb0, 0xb3,
};


#ifdef notdef
/*
 * send (233, 11)
 * should get ACK (75, 1, ... , 0)
 * should also generate a 0xe9, 0xfe (233, 254) response
 */
const uint8_t osp_pwr_mode[] = {	// input
  0xa0, 0xa2,                           // issue 9, 13
  0x00, 0x02,
  0xE9, 0x0B,				// 233, 11
  0x00, 0xf4,
  0xb0, 0xb3,
};


/*
 * (212, ...) Various Status messages
 * added after 2.4 (issue 9 and 13 have them)
 *
 */

/* pretty useless,  returns 1  which means 0.1 */
const uint8_t osp_revision_req[] = {    // input
  0xa0, 0xa2,                           // 9, 13
  0x00, 0x02,
  0xd4,                                 // 212 status
  0x07,
  0x00, 0xdb,
  0xb0, 0xb3,
};


/* not recognized */
const uint8_t osp_ephem_status[] = {    // input
  0xa0, 0xa2,                           // 9, 13
  0x00, 0x02,
  0xd4,                                 // 212 status
  0x01,
  0x00, 0xd5,
  0xb0, 0xb3,
};


uint8_t osp_almanac_status[] = {        // input
  0xa0, 0xa2,                           // 9, 13
  0x00, 0x02,
  0xd4,                                 // 212 status
  0x02,
  0x00, 0xd6,
  0xb0, 0xb3,
};
#endif

const uint8_t sirf_go_nmea[] = {        // input
  0xa0, 0xa2,                           // all
  0x00, 0x18,                           // len 24 (0x18)
  0x81,                                 // 129 set nmea
  2,                                    // mode, 0 enable nmea debug, 1 disable, 2 don't change.
  1, 1,                                 // GGA 1 sec period, checksum
  0, 1,                                 // GLL
  1, 1,                                 // GSA
  5, 1,                                 // GSV (5 sec period)
  1, 1,                                 // RMC
  0, 1,                                 // VTG
  0, 1,                                 // MSS
  0, 0,                                 // Unused
  0, 1,                                 // ZDA
  0, 0,                                 // Unused
  0x12, 0xc0,                           // Baud rate (4800) (big endian)
  0x01, 0x65,                           // checksum
  0xb0, 0xb3                            // end seq
};

#endif	/* __SIRF_H__ */
