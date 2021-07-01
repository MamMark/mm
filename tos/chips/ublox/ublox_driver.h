/*
 * Copyright (c) 2020, 2021 Eric B. Decker
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
 * Misc defines and constants for ublox chipsets.
 *
 * Internal definitions that the ublox gps driver needs for various
 * control functions.
 */

#ifndef __UBLOX_DRIVER_H__
#define __UBLOX_DRIVER_H__

/* get external definitions */
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
#define DT_GPS_PWR_DWN_TO      (5 * 1024)

/*
 * STANDBY_TO: how long to wait before checking for TXRDY down when going to standby
 * WAKE_DELAY: how to wait before turning TXRDY interrupt back on when waking up.
 */
#define DT_GPS_STANDBY_TO      10
#define DT_GPS_WAKE_DELAY      100


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

const uint8_t ubx_cfg_ant_poll[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_CFG, UBX_CFG_ANT,
  0x00, 0x00,
  0x19, 0x51,
};


const uint8_t ubx_cfg_ant_disable_all_pins[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_CFG, UBX_CFG_ANT,
  0x04, 0x00,                           /* len, 4 */
  0x00, 0x00,                           /* flags, all off, no recovery */
  0xff, 0xff,                           /* reconfig, OCD/SCD/Switch 31 */
  0x1b, 0xca,
};


const uint8_t ubx_cfg_ant_svcs_pio16_only[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_CFG, UBX_CFG_ANT,
  0x04, 0x00,                           /* len, 4 */
  0x01, 0x00,                           /* flags, svcs on, others off, no recovery  */
  0xf0, 0xff,                           /* reconfig, OCD/SCD/31 (off), pio16 Switch */
  0x0d, 0xb0,
};


/*
 * clear the permanent configuration, return to default
 *
 * clear/save/load 0x0000000b: nav/msg/ioPort configs
 * devMask:     17: SpiFlsh, EEPROM, Flash, BBR
 */
const uint8_t ubx_cfg_cfg_erase[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_CFG, UBX_CFG_CFG,
  0x0D, 0x00,                           /* length, 13 bytes */
  0x0b, 0x00, 0x00, 0x00,               /* clear mask */
  0x0b, 0x00, 0x00, 0x00,               /* save  mask */
  0x0b, 0x00, 0x00, 0x00,               /* load  mask */
  0x17,                                 /* devMask */
  0x54, 0xf9,
};

/*
 * save 0x0000000b: nav/msg/ioPort configs
 * devMask:     17: SpiFlsh, EEPROM, Flash, BBR
 */
const uint8_t ubx_cfg_cfg_save_devmask[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_CFG, UBX_CFG_CFG,
  0x0D, 0x00,                           /* length, 13 bytes */
  0x00, 0x00, 0x00, 0x00,               /* clear mask */
  0x0b, 0x00, 0x00, 0x00,               /* save  mask */
  0x00, 0x00, 0x00, 0x00,               /* load  mask */
  0x17,                                 /* devMask */
  0x3E, 0x33,
};

const uint8_t ubx_cfg_cfg_save[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_CFG, UBX_CFG_CFG,
  0x0C, 0x00,                           /* length, 12 bytes */
  0x00, 0x00, 0x00, 0x00,               /* clear mask */
  0x0b, 0x00, 0x00, 0x00,               /* save  mask */
  0x00, 0x00, 0x00, 0x00,               /* load  mask */
  0x26, 0xE7,
};

const uint8_t ubx_cfg_dat_poll[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_CFG, UBX_CFG_DAT,
  0x00, 0x00,
  0x0C, 0x2A,
};

const uint8_t ubx_cfg_gnss_poll[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_CFG, UBX_CFG_GNSS,
  0x00, 0x00,
  0x44, 0xD2,
};

const uint8_t ubx_cfg_inf_poll[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_CFG, UBX_CFG_INF,
  0x00, 0x00,
  0x08, 0x1E,
};

const uint8_t ubx_cfg_otp_dcdc_permanent[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_CFG, UBX_CFG_OTP,
  0x0c, 0x00,                           /* length, 12 bytes */
  0x00, 0x00,                           /* subcommand, write */
  0x03,                                 /* word number */
  0x1f,                                 /* efuse section */
  0xc5, 0x90, 0xe1, 0x9f,               /* salted hash */
  0xff, 0xff, 0xfe, 0xff,               /* 0xfe says perm enable dc-dc conv */\
  0x45, 0x79,                           /* checksum */
};

const uint8_t ubx_cfg_otp_poll[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_CFG, UBX_CFG_OTP,
  0x00, 0x00,
  0x47, 0xdb,                           /* checksum */
};

const uint8_t ubx_cfg_prt_poll_spi[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_CFG, UBX_CFG_PRT,
  0x01, 0x00,                           /* length, 1 byte */
  UBX_COM_PORT_SPI,
  0x0B, 0x25,
};

/*
 * tx-ready setting
 *
 * threshold 8 bytes (1)  << 7
 * pin      xx       (xx) << 2
 * pol       0       (0)  << 1   active high
 * tx-ready enabled  (1)  << 0
 *
 * pin is platform specific, PLATFORM_UBX_TXRDY_PIN
 *
 *        thres      |       pin    pol  en
 *  | 0 0 0 0 0 0 0 0 1 | x x x x x | 0 | 1 |
 */

/* dev7 uses the SparkFun ublox module, EXTINT is PIO13 */
#if    PLATFORM_UBX_TXRDY_PIN == 13
#define UBX_CFG_PRT_SPI_TXRDY_CHK 0x07, 0x4E

/* mm7 uses the ZoeQ module and preserves EXTINT, TXRDY is on PIO15 */
/* mm7 can also use PIO13 */
#elif  PLATFORM_UBX_TXRDY_PIN == 15
#define UBX_CFG_PRT_SPI_TXRDY_CHK 0x0F, 0xDE
#else
#error PLATFORM_UBX_TXRDY_PIN not defined
#endif

#define UBX_TXRDY_VAL   (((PLATFORM_UBX_TXRDY_PIN & 0x1f) << 2) | 0x81)

const uint8_t ubx_cfg_prt_spi_notxrdy[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_CFG, UBX_CFG_PRT,           /* Config Port */
  0x14, 0x00,                           /* length, 20 bytes */
  UBX_COM_PORT_SPI,                     /* port id */
  0x00,                                 /* reserved */
  0x00, 0x00,
  0x00, 0x32, 0x00, 0x00,               /* spi mode 0, ffCnt */
  0x00, 0x00, 0x00, 0x00,               /* reserved */
  0x01, 0x00,                           /* inProtoMask, Ubx */
  0x01, 0x00,                           /* outProtoMask, Ubx */
  0x00, 0x00,                           /* flags, no extendedTxTimeout */
  0x00, 0x00,                           /* reserved */
  0x52, 0x94,
};

/*
 * CFG-PRT-SPI
 *
 * enable txRdy on PinXX, turn off NMEA and RTCM, only UBX.
 */
const uint8_t ubx_cfg_prt_spi_txrdy[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_CFG, UBX_CFG_PRT,           /* Config Port */
  0x14, 0x00,                           /* length, 20 bytes */
  UBX_COM_PORT_SPI,                     /* port id */
  0x00,                                 /* reserved */
  UBX_TXRDY_VAL, 0x00,
  0x00, 0x32, 0x00, 0x00,               /* spi mode 0, ffCnt */
  0x00, 0x00, 0x00, 0x00,               /* reserved */
  0x01, 0x00,                           /* inProtoMask, Ubx */
  0x01, 0x00,                           /* outProtoMask, Ubx */
  0x00, 0x00,                           /* flags, no extendedTxTimeout */
  0x00, 0x00,                           /* reserved */
  UBX_CFG_PRT_SPI_TXRDY_CHK,
};

const uint8_t ubx_cfg_rate_poll[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_CFG, UBX_CFG_RATE,
  0x00, 0x00,
  0x0e, 0x30,
};

const uint8_t ubx_cfg_rst_full_hw[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_CFG, UBX_CFG_RST,
  0x04, 0x00,
  0xff, 0xff,                           /* clear all BBR */
  0x00,                                 /* resetMode: 0 HW_WDOG */
  0x00,                                 /* reserved */
  0x23, 0x9b,
};

const uint8_t ubx_cfg_rst_stop_gnss[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_CFG, UBX_CFG_RST,
  0x04, 0x00,                           /* len 4 bytes */
  0x00, 0x00,                           /* no clear, hot start if possible */
  0x08,                                 /* resetMode: 8 gnss stop */
  0x00,                                 /* reserved */
  0x16, 0x74,
};

const uint8_t ubx_cfg_tp5_poll[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_CFG, UBX_CFG_TP5,           /* time pulse 0 */
  0x00, 0x00,                           /* length, 0 bytes, poll */
  0x37, 0xAB,
};

const uint8_t ubx_cfg_tp5_0_poll[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_CFG, UBX_CFG_TP5,           /* time pulse 0 */
  0x01, 0x00,                           /* length, 1 bytes, poll */
  0x00,
  0x38, 0xE5,
};

const uint8_t ubx_cfg_tp5_1_poll[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_CFG, UBX_CFG_TP5,           /* time pulse 0 */
  0x01, 0x00,                           /* length, 1 bytes, poll */
  0x01,
  0x39, 0xE6,
};

const uint8_t ubx_mon_hw_poll[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_MON, UBX_MON_HW,
  0x00, 0x00,                           /* length, 0, poll */
  0x13, 0x43,
};

const uint8_t ubx_mon_io_poll[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_MON, UBX_MON_IO,
  0x00, 0x00,
  0x0C, 0x2E,
};

const uint8_t ubx_mon_llc_poll[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_MON, UBX_MON_LLC,           /* low level config */
  0x00, 0x00,                           /* length, 0, poll */
  0x17, 0x4f,
};

const uint8_t ubx_mon_ver_poll[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_MON, UBX_MON_VER,
  0x00, 0x00,                           /* length, 0, poll */
  0x0E, 0x34,
};


const uint8_t ubx_nav_aopstatus_poll[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_NAV, UBX_NAV_AOPSTATUS,
  0x00, 0x00,                           /* length, 0, poll */
  0x61, 0x24,
};

const uint8_t ubx_nav_orb_poll[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_NAV, UBX_NAV_ORB,
  0x00, 0x00,                           /* length, 0, poll */
  0x35, 0xa0,
};


const uint8_t ubx_rxm_pmreq_backup_0[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_RXM, UBX_RXM_PMREQ,
  0x10, 0x00,                           /* length, 16 bytes */
  0x00,                                 /* version */
  0x00, 0x00, 0x00,                     /* reserved1 */
  0x00, 0x00, 0x00, 0x00,               /* 0, no timeout   */
  0x06, 0x00, 0x00, 0x00,               /* force, backup   */
  0x80, 0x00, 0x00, 0x00,               /* wakeup, SPICS   */
  0xd9, 0x4b,
};


const uint8_t ubx_tim_tp_poll[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_TIM, UBX_TIM_TP,
  0x00, 0x00,                           /* length, 0 bytes, poll */
  0x0E, 0x37,
};


const uint8_t ubx_upd_sos_create[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_UPD, UBX_UPD_SOS,           /* save on shutdown */
  0x04, 0x00,                           /* length, 4 bytes  */
  0x00,                                 /* cmd 0, create    */
  0x00, 0x00, 0x00,
  0x21, 0xEC,
};

const uint8_t ubx_upd_sos_clear[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_UPD, UBX_UPD_SOS,           /* save on shutdown */
  0x04, 0x00,                           /* length, 4 bytes  */
  0x01,                                 /* cmd 1, clear     */
  0x00, 0x00, 0x00,
  0x22, 0xF0,
};

const uint8_t ubx_upd_sos_poll[] = {
  UBX_SYNC1,     UBX_SYNC2,
  UBX_CLASS_UPD, UBX_UPD_SOS,           /* save on shutdown */
  0x00, 0x00,                           /* length, 0 bytes  */
  0x22, 0xF0,
};


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
  uint16_t nmea_good;
  uint16_t nmea_too_big;
  uint16_t nmea_bad_chk;
} ubx_other_stats_t;

#endif  /* __UBLOX_DRIVER_H__ */
