/*
 * Copyright (c) 2008, 2010, 2017-2019 Eric B. Decker
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

/*************************************************************************
 *
 * Messages
 *
 * numerical order
 *
 *************************************************************************/

/*
 * resets
 *
 * reset mask values:
 *
 * x x 1 x x x x x  - enable debug  messages (mid 255)
 * x x x 1 x x x x  - enable navlib messages (mid 28-31)
 *
 * x x x x 0 x x x  - restart
 * x x x x 0 x x 0  - restart - ignore init values (except channels)
 * x x x x 0 x x 1  - restart - use    init values
 * x x x x 0 x 0 x  - restart - preserve ephemeri
 * x x x x 0 x 1 x  - restart - clear    ephemeri (nuke warm start)
 * x x x x 0 0 x x  - restart - preserve cold (see warm start above)
 * x x x x 0 1 x x  - restart - force cold start
 * 0 x x x 0 x x x  - restart gps (gps stop/gps start)
 * 1 x x x 0 x x x  - restart both gps and sys (ARM?)

 * x x x x 1 x x x  - factory reset
 * x x x x 1 x x 0  - factory reset - clear    flash/eerom
 * x x x x 1 x x 1  - factory reset - preserve flash/eerom
 * x x x x 1 a b x  - factory reset - port (ab/00 or 11 default)
 *                                    port (01 nema4800, 10 osp115200)
 * x 0 x x 1 x x x  - factory reset - preserve XO and CW config
 * x 1 x x 1 x x x  - factory reset - clear    XO and CW config
 *
 * 0x08             - factory reset,   default port config
 * 0x0c             - factory reset,   osp, 115200, clear eerom
 * 0x0d             - factory reset,   osp, 115200, preserve eerom
 * 0x12             - warmstart, navlib
 * 0x30             - gps restart,     navlib/debug, hotstart
 * 0x38             - factory reset,   navlib/debug
 * 0x80             - gps/sys restart
 */

/* factory reset, preserve eerom */
const uint8_t sirf_factory_reset[] = {
  0xa0, 0xa2,
  0x00, 0x19,
  128,                          // init data source (reset) (0x80)
  0, 0, 0, 0,                   // ecef x
  0, 0, 0, 0,                   // ecef y
  0, 0, 0, 0,                   // ecef z
  0, 0, 0, 0,                   // drift
  0, 0, 0, 0,                   // tow - ms (*100)
  0, 0,                         // xweek (extended week
  12,                           // nchannels, always 12
  0x0d,                         // reset mask, factory, osp, 115200, preserve eerom
  0x00, 0x99,
  0xb0, 0xb3,
};

/* factory reset and wipe the eeprom */
const uint8_t sirf_factory_clear[] = {
  0xa0, 0xa2,
  0x00, 0x19,
  128,                          // init data source (reset) (0x80)
  0, 0, 0, 0,                   // ecef x
  0, 0, 0, 0,                   // ecef y
  0, 0, 0, 0,                   // ecef z
  0, 0, 0, 0,                   // drift
  0, 0, 0, 0,                   // tow - ms (*100)
  0, 0,                         // xweek (extended week
  12,                           // nchannels, always 12
  0x08,                         // reset mask, factory, port default, clear eerom
  0x00, 0x98,
  0xb0, 0xb3,
};

const uint8_t sirf_warmstart_noinit[] = {
  0xa0, 0xa2,
  0x00, 0x19,
  128,                          // init data source (reset) (0x80)
  0, 0, 0, 0,                   // ecef x
  0, 0, 0, 0,                   // ecef y
  0, 0, 0, 0,                   // ecef z
  0, 0, 0, 0,                   // drift
  0, 0, 0, 0,                   // tow - ms (*100)
  0, 0,                         // xweek (extended week
  12,                           // nchannels, always 12
  0x02,                         // reset mask, warmstart (no ephem)
  0x00, 0x8e,
  0xb0, 0xb3,
};

const uint8_t sirf_hotstart_noinit[] = {
  0xa0, 0xa2,
  0x00, 0x19,
  128,                          // init data source (reset) (0x80)
  0, 0, 0, 0,                   // ecef x
  0, 0, 0, 0,                   // ecef y
  0, 0, 0, 0,                   // ecef z
  0, 0, 0, 0,                   // drift
  0, 0, 0, 0,                   // tow - ms (*100)
  0, 0,                         // xweek (extended week
  12,                           // nchannels, always 12
  0x00,                         // reset mask, hotstart (no ephem)
  0x00, 0x8c,
  0xb0, 0xb3,
};

const uint8_t sirf_warmstart_navlib_noinit[] = {
  0xa0, 0xa2,
  0x00, 0x19,
  128,                          // init data source (reset) (0x80)
  0, 0, 0, 0,                   // ecef x
  0, 0, 0, 0,                   // ecef y
  0, 0, 0, 0,                   // ecef z
  0, 0, 0, 0,                   // drift
  0, 0, 0, 0,                   // tow - ms (*100)
  0, 0,                         // xweek (extended week
  12,                           // nchannels, always 12
  0x12,                         // reset mask, warmstart (no ephem), navlib
  0x00, 0x9e,
  0xb0, 0xb3,
};

const uint8_t sirf_swver[] = {
  0xa0, 0xa2,
  0x00, 0x02,
  132,                          // send sw ver (0x84)
  0x00,
  0x00, 0x84,
  0xb0, 0xb3,
};

const uint8_t sirf_sbas_enable[] = {
  0xa0, 0xa2,                   // start seq
  0x00, 0x07,                   // length 7
  133,                          // dgps source
  1,                            // SBAS enable
  0, 0, 0, 0,                   // beacon freq (n.u.)
  0,                            // beacon bit rate (n.u.)
  0x00, 0x86,                   // checksum
  0xb0, 0xb3,                   // end seq
};

const uint8_t sirf_set_mode_degrade[] = {
  0xa0, 0xa2,                   // start seq
  0x00, 0x0E,                   // length 14
  136,                          // set mode
  0, 0,                         // reserved
  3,                            // degraded mode, accept 3 SV solutions
  1,                            // position calc mode
  0,                            // reserved
  0, 0,                         // altitude for alt hold
  0,                            // alt hold mode
  0,                            // alt hold src, last computed
  0,                            // reserved
  5,                            // degraded time out
  0,                            // DR time out
  0,                            // Meas/Track smoothing
  0x00, 0x91,                   // checksum
  0xb0, 0xb3,                   // end seq
};

const uint8_t sirf_sbas_auto[] = {
  0xa0, 0xa2,                   // start seq
  0x00, 0x03,                   // length 3
  138,                          // dgps control
  0,                            // selection, auto
  0xff,                         // timeout, max
  0x01, 0x89,                   // checksum
  0xb0, 0xb3,                   // end seq
};

const uint8_t sirf_poll_clk_status[] = {
  0xa0, 0xa2,
  0x00, 0x02,
  144,                          // poll clock status (0x90)
  0x00,
  0x00, 0x90,
  0xb0, 0xb3,
};

const uint8_t sirf_2_off[] = {          /* navdata */
  0xa0, 0xa2, 0x00, 0x08,
  166,  0,    2,    0,    0, 0, 0, 0,
  0x00, 0xa8, 0xb0, 0xb3,
};

const uint8_t sirf_2_on[] = {           /* navdata */
  0xa0, 0xa2, 0x00, 0x08,
  166,  0,    2,    1,    0, 0, 0, 0,
  0x00, 0xa9, 0xb0, 0xb3,
};

const uint8_t sirf_4_off[] = {          /* navtrack */
  0xa0, 0xa2, 0x00, 0x08,
  166,  0,    4,    0,    0, 0, 0, 0,
  0x00, 0xaa, 0xb0, 0xb3,
};

const uint8_t sirf_4_on[] = {           /* navtrack */
  0xa0, 0xa2, 0x00, 0x08,
  166,  0,    4,    1,    0, 0, 0, 0,
  0x00, 0xab, 0xb0, 0xb3,
};

const uint8_t sirf_7_on[] = {           /* clk status   */
  0xa0, 0xa2, 0x00, 0x08,               /* enable 1/sec */
  166,  0,    7,   1,    0, 0, 0, 0,
  0x00, 0xae, 0xb0, 0xb3,
};

const uint8_t sirf_9_off[] = {          /* cpu  thruput */
  0xa0, 0xa2, 0x00, 0x08,
  166,  0,    9,    0,    0, 0, 0, 0,
  0x00, 0xaf, 0xb0, 0xb3,
};

const uint8_t sirf_41_off[] = {         /* geodata */
  0xa0, 0xa2, 0x00, 0x08,
  166,  0,    41,   0,    0, 0, 0, 0,
  0x00, 0xcf, 0xb0, 0xb3,
};

const uint8_t sirf_41_on[] = {          /* geodata */
  0xa0, 0xa2, 0x00, 0x08,
  166,  0,    41,   1,    0, 0, 0, 0,
  0x00, 0xd0, 0xb0, 0xb3,
};

const uint8_t sirf_51_off[] = {         /* unk_51 */
  0xa0, 0xa2, 0x00, 0x08,
  166,  0,    51,   0,    0, 0, 0, 0,
  0x00, 0xd9, 0xb0, 0xb3,
};

const uint8_t sirf_92_off[] = {         /* cw */
  0xa0, 0xa2, 0x00, 0x08,
  166,  0,    92,   0,    0, 0, 0, 0,
  0x01, 0x02, 0xb0, 0xb3,
};

const uint8_t sirf_93_off[] = {         /* tcxo */
  0xa0, 0xa2, 0x00, 0x08,
  166,  0,    93,   0,    0, 0, 0, 0,
  0x01, 0x03, 0xb0, 0xb3,
};

const uint8_t sirf_225_off[] = {        /* stats */
  0xa0, 0xa2, 0x00, 0x08,
  166,  0,    225,  0,    0, 0, 0, 0,
  0x01, 0x87, 0xb0, 0xb3,
};

const uint8_t sirf_msgs_all_off[] = {
  0xa0, 0xa2,                   // start seq
  0x00, 0x08,                   // length 8
  166,                          // set message rate
  2,                            // mode 2 enable/disable all
  0,                            // mid
  0,                            // 0 - all off
  0, 0, 0, 0,                   // reserved
  0x00, 0xa8,                   // checksum
  0xb0, 0xb3                    // end seq
};

/* nuke after done messing around, testing */
const uint8_t sirf_msgs_all_on[] = {
  0xa0, 0xa2,                   // start seq
  0x00, 0x08,                   // length 8
  166,                          // set message rate
  2,                            // mode 2 enable/disable all
  0,                            // mid
  1,                            // 1 - all on, 1/sec
  0, 0, 0, 0,                   // reserved
  0x00, 0xa9,                   // checksum
  0xb0, 0xb3                    // end seq
};


/*
 * the demo program (sirfLive) outputs this message with len 5 eh?
 * the manual (DCP15) says len 6
 *
 * a0 a2 00 05 aa 00 00 00 00 00 aa b0 b3          sbas params
 *
 * for now send both.  Look for Acks.
 *
 * can we actually send back to back and have them work?
 */
const uint8_t sirf_sbas_params_6[] = {
  0xa0, 0xa2,                   // start seq
  0x00, 0x06,                   // length 6
  170,                          // sbas params
  0,                            // auto mode
  1,                            // integrity mode
  0,                            // flag bits, none
  0,                            // region, 0 - auto
  0,                            // regionPrn - n. u.
  0x00, 0xab,                   // checksum
  0xb0, 0xb3,                   // end seq
};

const uint8_t sirf_sbas_params_5[] = {
  0xa0, 0xa2,                   // start seq
  0x00, 0x05,                   // length 5
  170,                          // sbas params
  0,                            // auto mode
  1,                            // integrity mode
  0,                            // flag bits, none
  0,                            // region, 0 - auto
  0x00, 0xab,                   // checksum
  0xb0, 0xb3,                   // end seq
};


const uint8_t sirf_peek_0[] = {
  0xa0, 0xa2,                   // start seq
  0x00, 0x0c,                   // length 12
  178, 3,                       // peek/poke
  0,                            // type, peek
  4,                            // 4 bytes
  0, 0, 0, 0,                   // addr 0
  0, 0, 0, 0,                   // dummy data
  0x00, 0xb9,                   // checksum
  0xb0, 0xb3                    // end seq
};


/*
 * almanac/ephemeris status request
 */

const uint8_t sirf_ephemeris_status[] = {
  0xa0, 0xa2,                   // start seq
  0x00, 0x02,                   // length 2
  212,  1,                      // ephemeris status request
  0x00, 0xd5,                   // checksum
  0xb0, 0xb3                    // end seq
};

const uint8_t sirf_almanac_status[] = {
  0xa0, 0xa2,                   // start seq
  0x00, 0x02,                   // length 2
  212,  2,                      // almanac status request
  0x00, 0xd6,                   // checksum
  0xb0, 0xb3                    // end seq
};


const uint8_t sirf_timefreq_status[] = {
  0xa0, 0xa2,                   // start seq
  0x00, 0x02,                   // length 2
  212,  4,                      // time frequency status
  0x0f,                         // time status, time accuracy
                                // freq status, approx position
  0x00, 0xe7,                   // checksum
  0xb0, 0xb3                    // end seq
};


const uint8_t sirf_poll_almanac[] = {
  0xa0, 0xa2,                   // start seq
  0x00, 0x02,                   // length 2
  146,                          // poll almanac
  00,                           // control not used
  0x00, 0x92,                   // checksum
  0xb0, 0xb3                    // end seq
};

const uint8_t sirf_poll_ephemeris[] = {
  0xa0, 0xa2,                   // start seq
  0x00, 0x03,                   // length 3
  147,                          // poll ephemeris
  00,                           // sv_id, 0 for all
  00,                           // control not used
  0x00, 0x93,                   // checksum
  0xb0, 0xb3                    // end seq
};

/*
 * hw_config_rsp: respond to hw_config_req
 *
 * hw config byte 0x00: (bit numbering 1 based in manual)
 *   b0: Precise Time Transfer off
 *   b1: PTT direction  CP -> SLC (gps)
 *   b2: Freq Transfer off
 *   b3: Counter
 *   b4: RTC Availablity (0 - no, 1 - RTC available)
 *   b5: RTC for GPS (0 - external?, 1 - internal?)
 *   b6: Coarse Time Avail (0 - no)
 *   b7: ref clock on
 *
 * We set b4 and b5.
 */

const uint8_t sirf_hw_config_rsp[] = {
  0xa0, 0xa2,                   // start seq
  0x00, 0x08,                   // length 8
  214,                          // HW Config Response, no sid
  0x30,                         // see above
  0, 0, 0, 0, 0,                // nominal freq (not used).
  0,                            // Network enhance (not used).
  0x00, 0xd6,                   // checksum
  0xb0, 0xb3                    // end seq
};


const uint8_t sirf_go_mpm_0[] = {
  0xa0, 0xa2,                   // start seq
  0x00, 0x06,                   // length 6
  218, 2,                       // Req Pwr Mode, MPM
  0,                            // time_out, 0 immediate MPM
  4,                            // control, RTC uncertainty, 250us (default)
                                // reserved bit (return mpm status?)
  0, 0,                         // reserved
  0x00, 0xe0,                   // checksum
  0xb0, 0xb3                    // end seq
};

const uint8_t sirf_go_mpm_7f[] = {
  0xa0, 0xa2,                   // start seq
  0x00, 0x06,                   // length 6
  218, 2,                       // Req Pwr Mode, MPM
  0x7f,                         // time_out, 0 immediate MPM
  0,                            // control, RTC uncertainty, 250us (default)
  0, 0,                         // reserved
  0x01, 0x5b,                   // checksum
  0xb0, 0xb3                    // end seq
};

const uint8_t sirf_go_mpm_ff[] = {
  0xa0, 0xa2,                   // start seq
  0x00, 0x06,                   // length 6
  218,  2,                      // Req Pwr Mode, MPM
  0xff,                         // time_out, 0 immediate MPM
  0,                            // control, RTC uncertainty, 250us (default)
  0, 0,                         // reserved
  0x01, 0xdb,                   // checksum
  0xb0, 0xb3                    // end seq
};


const uint8_t sirf_ee_poll_ephemeris[] = {
  0xa0, 0xa2,                   // start seq
  0x00, 0x06,                   // length 6
  232,  2,                      // ee - poll ephemeris
  0xff, 0xff, 0xff, 0xff,       // sat mask (only 12 lowest)
  0x04, 0xe6,                   // checksum
  0xb0, 0xb3                    // end seq
};


const uint8_t sirf_ee_age[] = {
  0xa0, 0xa2,                   // start seq
  0x00, 0x12,                   // length 18
  232,  25,                     // ee - age
  1,    1,                      // num sats, prn
  0,                            // ephPosFlag
  0,    0,                      // eePosAge
  0,    0,                      // cgeePosGPSWeek
  0,    0,                      // cgeePosTOE
  0,                            // ephClkFlag
  0,    0,                      // eeClkAge
  0,    0,                      // cgeeClkGPSWeek
  0,    0,                      // cgeeClkTOE
  0x01, 0x03,                   // checksum
  0xb0, 0xb3                    // end seq
};


/* 232/32: sgee off, cgee on */
const uint8_t sirf_cgee_enable[] = {
  0xa0, 0xa2,                   // start seq
  0x00, 0x04,                   // length 4
  232,  32,                     // sif aiding enable/disable
  1,                            // sgee disable
  0,                            // cgee enable
  0x01, 0x09,                   // checksum
  0xb0, 0xb3,                   // end seq
};


const uint8_t sirf_ee_sif_aiding_status[] = {
  0xa0, 0xa2,                   // start seq
  0x00, 0x03,                   // length 3
  232,  33,                     // get sif aiding status
  0,                            // reserved
  0x01, 0x09,                   // checksum
  0xb0, 0xb3                    // end seq
};


const uint8_t sirf_ee_eerom_host[] = {
  0xa0, 0xa2,                   // start seq
  0x00, 0x03,                   // length 3
  232,  253,                    // ee - storage control
  0,                            // set to host
  0x01, 0xe5,                   // checksum
  0xb0, 0xb3                    // end seq
};

/* 232/253: eerom_on, eerom ext flash */
const uint8_t sirf_ee_eerom_spi[] = {
  0xa0, 0xa2,                   // start seq
  0x00, 0x03,                   // length 3
  232,  253,                    // ee - storage control
  2,                            // store ee to spi flash
  0x01, 0xe7,                   // checksum
  0xb0, 0xb3                    // end seq
};


const uint8_t sirf_ee_eerom_off[] = {
  0xa0, 0xa2,                   // start seq
  0x00, 0x03,                   // length 3
  232,  253,                    // ee - storage control
  3,                            // off
  0x01, 0xe8,                   // checksum
  0xb0, 0xb3                    // end seq
};


/*
 * cgee prediction control
 * enable/disable
 */
const uint8_t sirf_cgee_pred_enable[] = {
  0xa0, 0xa2,                   // start seq
  0x00, 0x06,                   // length 6
  232,  254,                    // ee - storage control
  0xff, 0xff, 0xff, 0xff,       // permanently enable
  0x05, 0xe2,                   // checksum
  0xb0, 0xb3                    // end seq
};


const uint8_t sirf_cgee_pred_disable[] = {
  0xa0, 0xa2,                   // start seq
  0x00, 0x06,                   // length 6
  232,  254,                    // ee - storage control
  0, 0, 0, 0,                   // permanently disable
  0x01, 0xe6,                   // checksum
  0xb0, 0xb3                    // end seq
};


/*
 * Extended Ephemeris Debug
 * 232, 255
 * unknown control cell (4 bytes)
 */
const uint8_t sirf_ee_debug[] = {
  0xa0, 0xa2,                   // start seq
  0x00, 0x06,                   // length 6
  232,  255,                    // ee - debug
  0xff, 0xff, 0xff, 0xff,       // debug flag
  0x05, 0xe3,                   // checksum
  0xb0, 0xb3                    // end seq
};


/*************************************************************************
 *
 * Sequences
 *
 *************************************************************************
 */

const uint8_t *boot_seq[] = {
  sirf_swver,
  sirf_poll_clk_status,
  sirf_4_on,                            /* navtrack */
  NULL,
};

const uint8_t *start_seq[] = {
  sirf_4_on,                            /* navtrack */
  NULL,
};

const uint8_t *cgee_seq[] = {
  sirf_ee_eerom_spi,
  sirf_cgee_enable,
  sirf_cgee_pred_enable,
  NULL,
};

const uint8_t *sbas_seq[] = {
  sirf_sbas_enable,
  sirf_sbas_auto,
  sirf_sbas_params_6,
  sirf_sbas_params_5,
  NULL,
};


/*************************************************************************
 *
 * speed change messages
 *
 *************************************************************************
 */

#ifdef notdef
const uint8_t nmea_4800[] = {
  '$', 'P', 'S', 'R', 'F',              // header
  '1', '0', '0', ',',                   // set serial port MID
  '1', ',',                             // protocol 0 SirfBinary, 1 - NEMA
  '4', '8', '0', '0', ',',              // baud rate
  '8', ',',                             // 8 data bits
  '1', ',',                             // 1 stop bit
  '0',                                  // no parity
  '*', '0', 'E',                        // checksum
  '\r', '\n'                            // terminator
};

const uint8_t nmea_9600[] = {
  '$', 'P', 'S', 'R', 'F',              // header
  '1', '0', '0', ',',                   // set serial port MID
  '1', ',',                             // protocol 0 SirfBinary, 1 - NEMA
  '9', '6', '0', '0', ',',              // baud rate
  '8', ',',                             // 8 data bits
  '1', ',',                             // 1 stop bit
  '0',                                  // no parity
  '*', '0', 'D',                        // checksum
  '\r', '\n'                            // terminator
};

const uint8_t nmea_57600[] = {
  '$', 'P', 'S', 'R', 'F',              // header
  '1', '0', '0', ',',                   // set serial port MID
  '1', ',',                             // protocol 0 SirfBinary, 1 - NEMA
  '5', '7', '6', '0', '0', ',',         // baud rate
  '8', ',',                             // 8 data bits
  '1', ',',                             // 1 stop bit
  '0',                                  // no parity
  '*', '3', '6',                        // checksum
  '\r', '\n'                            // terminator
};

const uint8_t nmea_115200[] = {
  '$', 'P', 'S', 'R', 'F',              // header
  '1', '0', '0', ',',                   // set serial port MID
  '1', ',',                             // protocol 0 SirfBinary, 1 - NEMA
  '1', '1', '5', '2', '0', '0', ',',    // baud rate
  '8', ',',                             // 8 data bits
  '1', ',',                             // 1 stop bit
  '0',                                  // no parity
  '*', '0', '5',                        // checksum
  '\r', '\n'                            // terminator
};

const uint8_t nmea_307200[] = {
  '$', 'P', 'S', 'R', 'F',              // header
  '1', '0', '0', ',',                   // set serial port MID
  '1', ',',                             // protocol 0 SirfBinary, 1 - NEMA
  '3', '0', '7', '2', '0', '0', ',',    // baud rate
  '8', ',',                             // 8 data bits
  '1', ',',                             // 1 stop bit
  '0',                                  // no parity
  '*', '0', '4',                        // checksum
  '\r', '\n'                            // terminator
};

const uint8_t nmea_921600[] = {
  '$', 'P', 'S', 'R', 'F',              // header
  '1', '0', '0', ',',                   // set serial port MID
  '1', ',',                             // protocol 0 SirfBinary, 1 - NEMA
  '9', '2', '1', '6', '0', '0', ',',    // baud rate
  '8', ',',                             // 8 data bits
  '1', ',',                             // 1 stop bit
  '0',                                  // no parity
  '*', '0', 'E',                        // checksum
  '\r', '\n'                            // terminator
};

const uint8_t nmea_1228800[] = {
  '$', 'P', 'S', 'R', 'F',              // header
  '1', '0', '0', ',',                   // set serial port MID
  '1', ',',                             // protocol 0 SirfBinary, 1 - NEMA
  '1', '2', '2', '8', '8', '0', '0', ',', // baud rate
  '8', ',',                             // 8 data bits
  '1', ',',                             // 1 stop bit
  '0',                                  // no parity
  '*', '3', '3',                        // checksum
  '\r', '\n'                            // terminator
};

const uint8_t nmea_swver[] = {
  '$', 'P', 'S', 'R', 'F',              // header
  '1', '2', '5',                        // swver MID
  '*', '2', '1',
  '\r', '\n'                            // terminator
};

const uint8_t nmea_sirf_307200[] = {
  '$', 'P', 'S', 'R', 'F',              // header
  '1', '0', '0', ',',                   // set serial port MID
  '0', ',',                             // protocol 0 SirfBinary, 1 - NEMA
  '3', '0', '7', '2', '0', '0', ',',    // baud rate
  '8', ',',                             // 8 data bits
  '1', ',',                             // 1 stop bit
  '0',                                  // no parity
  '*', '0', '5',                        // checksum
  '\r', '\n'                            // terminator
};
#endif

const uint8_t nmea_sirf_9600[] = {
  '$', 'P', 'S', 'R', 'F',              // header
  '1', '0', '0', ',',                   // set serial port MID
  '0', ',',                             // protocol 0 SirfBinary, 1 - NEMA
  '9', '6', '0', '0', ',',              // baud rate
  '8', ',',                             // 8 data bits
  '1', ',',                             // 1 stop bit
  '0',                                  // no parity
  '*', '0', 'C',                        // checksum
  '\r', '\n'                            // terminator
};

const uint8_t nmea_sirf_19200[] = {
  '$', 'P', 'S', 'R', 'F',              // header
  '1', '0', '0', ',',                   // set serial port MID
  '0', ',',                             // protocol 0 SirfBinary, 1 - NEMA
  '1', '9', '2', '0', '0', ',',         // baud rate
  '8', ',',                             // 8 data bits
  '1', ',',                             // 1 stop bit
  '0',                                  // no parity
  '*', '3', '9',                        // checksum
  '\r', '\n'                            // terminator
};

const uint8_t nmea_sirf_38400[] = {
  '$', 'P', 'S', 'R', 'F',              // header
  '1', '0', '0', ',',                   // set serial port MID
  '0', ',',                             // protocol 0 SirfBinary, 1 - NEMA
  '3', '8', '4', '0', '0', ',',         // baud rate
  '8', ',',                             // 8 data bits
  '1', ',',                             // 1 stop bit
  '0',                                  // no parity
  '*', '3', 'C',                        // checksum
  '\r', '\n'                            // terminator
};

const uint8_t nmea_sirf_57600[] = {
  '$', 'P', 'S', 'R', 'F',              // header
  '1', '0', '0', ',',                   // set serial port MID
  '0', ',',                             // protocol 0 SirfBinary, 1 - NEMA
  '5', '7', '6', '0', '0', ',',         // baud rate
  '8', ',',                             // 8 data bits
  '1', ',',                             // 1 stop bit
  '0',                                  // no parity
  '*', '3', '7',                        // checksum
  '\r', '\n'                            // terminator
};

const uint8_t nmea_sirf_115200[] = {
  '$', 'P', 'S', 'R', 'F',              // header
  '1', '0', '0', ',',                   // set serial port MID
  '0', ',',                             // protocol 0 SirfBinary, 1 - NEMA
  '1', '1', '5', '2', '0', '0', ',',    // baud rate
  '8', ',',                             // 8 data bits
  '1', ',',                             // 1 stop bit
  '0',                                  // no parity
  '*', '0', '4',                        // checksum
  '\r', '\n'                            // terminator
};


#ifdef notdef
const uint8_t sirf_nmea_4800[] = {
  0xa0, 0xa2,                   // start seq
  0x00, 0x18,                   // len 24 (0x18)
  129,                          // set nmea
  2,                            // mode, 0 enable nmea debug, 1 disable, 2 no change
  1, 1,                         // GGA 1 sec period, checksum
  0, 1,                         // GLL
  1, 1,                         // GSA
  5, 1,                         // GSV (5 sec period)
  1, 1,                         // RMC
  0, 1,                         // VTG
  0, 1,                         // MSS
  0, 0,                         // EPE
  0, 1,                         // ZDA
  0, 0,                         // Unused
  0x12, 0xc0,                   // Baud rate (4800) (big endian)
  0x01, 0x65,                   // checksum [0x01, 0x65]
  0xb0, 0xb3                    // end seq
};
#endif


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

const uint8_t sirf_19200[] = {
  0xa0, 0xa2,
  0x00, 0x09,
  134,                          // set binary serial port, 0x86
  0x00, 0x00,
  0x4b, 0x00,                   // 19200
  0x08, 0x01,                   // 8 bits, 1 stop
  0x00, 0x00,                   // no parity, pad
  0x00, 0xda,
  0xb0, 0xb3,
};

const uint8_t sirf_38400[] = {
  0xa0, 0xa2,
  0x00, 0x09,
  134,                          // set binary serial port, 0x86
  0x00, 0x00,
  0x96, 0x00,                   // 38400
  0x08, 0x01,                   // 8 bits, 1 stop
  0x00, 0x00,                   // no parity, pad
  0x01, 0x25,
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

#ifdef notdef
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
#endif


/*************************************************************************
 *
 * Internal data structures
 *
 *************************************************************************
 */
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
 *
 * majority of instrumentation stats are defined by the
 * dt_gps_proto_stats_t structure in typed_data.h.
 */

typedef struct {
  uint16_t no_buffer;                 /* no buffer/msg available */
  uint16_t max_seen;                  /* max legal seen */
  uint16_t largest_seen;              /* largest packet length seen */
} sirfbin_other_stats_t;

#endif  /* __SIRF_DRIVER_H__ */
