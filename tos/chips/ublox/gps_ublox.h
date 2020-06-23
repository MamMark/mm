/*
 * Copyright (c) 2020, Eric B. Decker
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
 * GPS platform defines
 */

#ifndef __GPS_UBLOX_H__
#define __GPS_UBLOX_H__

#include <ublox_msg.h>

#define GPS_LOG_EVENTS

/*
 * PWR_UP_DELAY
 *
 * When the GPS has been powered off, we need to wait for power
 * stabilization and a further delay for the chip to be ready.
 *
 * Once the chip has powered up, we first drain the spi pipe, then
 * start sending any configuration packets.  The first packet sent
 * enables the gps_txrdy functionailty.
 */

/* mis units */
#define DT_GPS_PWR_UP_DELAY     128


/*
 * u-blox spi interfaces have the following spec:
 *
 * max bit clock: 5.5 MHz,  min bit time 182 ns
 * max byte freq: 125 KBps, min byte time  8 us
 *
 *             DCOCLK       SMCLK                 SPICLK
 * We clock at 16 MiHz/2 => 8 MiHz / UBLOX_DIV => 2 MiHz
 *
 * Using DMA to access the spi pipe is problematic.  Expensive.  So we
 * clock the spi at 2 MiHz (using MSP432_UBLOX_DIV 4) which gives a bit
 * time of 500ns (> 182ns).  And access the SPI pipe using direct access,
 * which results in a interbyte time of approx. 17us (> 8us).   XXX FIXME
 */

/* this is a deadman timer to catch a hung RX path.  Shouldn't ever happen */
#define DT_GPS_MAX_RX_TIMEOUT   1024

const uint8_t ubx_cfg_prt_poll_spi[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_CFG, UBX_CFG_PRT,
  0x01, 0x00,                           /* length, 1 byte */
  UBX_COM_PORT_SPI,
  0x0B, 0x25,
};

const uint8_t ubx_mon_hw_poll[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_MON, UBX_MON_HW,
  0x00, 0x00,                           /* length, 0, poll */
  0x13, 0x43,
};

const uint8_t ubx_mon_ver_poll[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_MON, UBX_MON_VER,
  0x00, 0x00,                           /* length, 0, poll */
  0x0E, 0x34,
};


/* tx-ready setting
 *
 * threshold 8 bytes (1),      << 7
 * pin      13       (13, 0xd) << 2
 * pol       0       (0)       << 1
 * tx-ready enabled  (1)       << 0
 *
 *        thres      |       pin    pol  en
 *  | 0 0 0 0 0 0 0 0 1 | 0 1 1 0 1 | 0 | 1 |
 */

#define UBX_TXRDY_VAL   0xb5

const uint8_t ubx_cfg_prt_spi_notxrdy[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_CFG, UBX_CFG_PRT,           /* Config Port */
  0x14, 0x00,                           /* length, 20 bytes */
  UBX_COM_PORT_SPI,                     /* port id */
  0x00,                                 /* reserved */
  0x00, 0x00,
  0x00, 0x32, 0x00, 0x00,               /* spi mode 0, ffCnt */
  0x00, 0x00, 0x00, 0x00,               /* reserved */
  0x07, 0x00,                           /* inProtoMask, Rtcm, Nmea, Ubx */
  0x03, 0x00,                           /* outProtoMask, Nmea, Ubx */
  0x00, 0x00,                           /* flags, no extendedTxTimeout */
  0x00, 0x00,                           /* reserved */
  0x5a, 0xd0,
};

const uint8_t ubx_cfg_prt_spi_txrdy[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_CFG, UBX_CFG_PRT,           /* Config Port */
  0x14, 0x00,                           /* length, 20 bytes */
  UBX_COM_PORT_SPI,                     /* port id */
  0x00,                                 /* reserved */
  UBX_TXRDY_VAL, 0x00,
  0x00, 0x32, 0x00, 0x00,               /* spi mode 0, ffCnt */
  0x00, 0x00, 0x00, 0x00,               /* reserved */
  0x07, 0x00,                           /* inProtoMask, Rtcm, Nmea, Ubx */
  0x03, 0x00,                           /* outProtoMask, Nmea, Ubx */
  0x00, 0x00,                           /* flags, no extendedTxTimeout */
  0x00, 0x00,                           /* reserved */
  0x0F, 0x8A,
};

#endif /* __GPS_UBLOX_H__ */
