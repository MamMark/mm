#ifndef __SI446X_CONFIG_DEVICE_H__
#define __SI446X_CONFIG_DEVICE_H__

/*
 * Copyright (c) 2016-2017 Eric B. Decker, Daniel J. Maltbie
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the copyright holder nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * Author: Eric B. Decker
 * Date: 1/15/2016
 * Author: Daniel J. Maltbie <dmaltbie@daloma.org>
 * Date: 5/20/2017
 *
 */

/**************************************************************************/

/*  ---  Driver dependent Device Config
 *
 * SI446X_GPIO_PIN_CFG_LEN and SI446X_RF_GPIO_PIN_CFG are provided by platform
 * dependent code and are in radio_platform_si446x.h.  See platform code,
 * tos/platform/<platform>/hardware/si446x/...
 */

/*
 * GLOBAL_CONFIG:(p0003), sequencer_mode (FAST), fifo_mode (HALF_DUPLEX FIFO)
 *     protocol (0, GENERIC), power_mode (0, HIGH_PERF).
 *
 * fifo_mode HALF_DUPLEX yields a unified 129 byte fifo.
 * 0003 <- 0x60, split fifo,   empty_tx_len 64
 * 0003 <- 0x70, unified fifo, empty_tx_len 129
 */
#define SI446X_GLOBAL_CONFIG_1_LEN      5
#define SI446X_GLOBAL_CONFIG_1          0x11, 0x00, 0x01, 0x03, 0x60

/*
 * Interrupt Control
 */
#define SI446X_INT_CTL_ENABLE_4_LEN     8
#define SI446X_INT_CTL_ENABLE_4         0x11, 0x01, 0x04, 0x00,  \
                                        SI446X_INT_STATUS_CHIP_INT_STATUS        \
                                            | SI446X_INT_STATUS_MODEM_INT_STATUS \
                                            | SI446X_INT_STATUS_PH_INT_STATUS,   \
                                        SI446X_PH_INTEREST,                      \
                                        SI446X_MODEM_INTEREST,                   \
                                        SI446X_CHIP_INTEREST

/*

start check here

 * PREAMBLE: (p1000+)
 *
 * TX_LENGTH:   8 bytes (64bits)
 * CONFIG_STD_1:RX_THRESH (0x14) 20 bits, do not skip SYNC
 * CONFIG_NSTD: not used, 0x00
 * CONFIG_STD_2: TIMEOUT_EXTENDED 0, TIMEOUT: 0xf 60 bit time out
 * PREAMBLE_CONFIG: 0x31, 1 tx first, tx_length in bytes, no manchester, pre_1010
 */
#define SI446X_PREAMBLE_LEN             9
#define SI446X_PREAMBLE                 0x11, 0x10, 0x09, 0x00, 0x08, 0x14, 0x00, 0x0f, 0x31

/*
 * Various Pkt configs: (p1200+)
 *
 * CRC_CONFIG: 0x85, CRC_SEED, POLY 5 CCITT_16
 * various whitening
 * CONFIG1: 0x82, PH_FIELD_SPLIT, CRC_ENDIAN msb, bit_order msb
 *
 * TX and RX fields are split.  Different field definitions are used for TX
 * and RX.  See documentation on TX and RX at the front of this file.
 */
#define SI446X_PKT_CRC_CONFIG_7_LEN     11
#define SI446X_PKT_CRC_CONFIG_7         0x11, 0x12, 0x07, 0x00, \
                                              0x85, 0x01, 0x08, 0xFF, 0xFF, 0x00, 0x82

#define SI446X_PKT_LEN_5_LEN            9
#define SI446X_PKT_LEN_5                0x11, 0x12, 0x05, 0x08, \
                                              0x2a, 0x01, 0x00, 0x30, 0x30

#define SI446X_PKT_TX_FIELD_CONFIG_6_LEN 10
#define SI446X_PKT_TX_FIELD_CONFIG_6    0x11, 0x12, 0x06, 0x0d, \
                                              0x00, 0x01, 0x04, 0xa2, \
                                              0x00, 0x00

#define SI446X_PKT_RX_FIELD_CONFIG_10_LEN 14
#define SI446X_PKT_RX_FIELD_CONFIG_10   0x11, 0x12, 0x0a, 0x21, \
                                              0x00, 0x01, 0x04, 0x82, \
                                              0x00, 0xff, 0x00, 0x0a, \
                                              0x00, 0x00

/* MODEM_RSSI (p204a+)
 *
 * MODEM_RSSI_THRESH (p204a): set to INITIAL_RSSI_THRESH
 * MODEM_RSSI_JUMP_THRESH:    default 0xc (not used)
 * MODEM_RSSI_CONTROL:        CHECK_THRESH_AT_LATCH 1
 *                            AVERAGE: 0 (updated every bit time, average of 4 bit times)
 *                            LATCH: 2 SYNC, latch when sync detected
 */
#define SI446X_MODEM_RSSI_LEN           7
#define SI446X_MODEM_RSSI               0x11, 0x20, 0x03, 0x4a,  \
                                        SI446X_INITIAL_RSSI_THRESH, 0x0c, 0x22

#define SI446X_PKT_THRESH_LEN           6
#define SI446X_PKT_THRESH               0x11, 0x12, 0x02, 0x0b,  \
                                        0x28, 0x19

#define SI446X_PA_LEVEL_LEN             5
#define SI446X_PA_LEVEL                 0x11, 0x22, 0x01, 0x01,  \
                                        0x35


/**************************************************************************/

/*
 * Device Config, driver/hw dependent
 */
const uint8_t si446x_device_config[] = {
  SI446X_GPIO_PIN_CFG_LEN,           SI446X_RF_GPIO_PIN_CFG,
  SI446X_GLOBAL_CONFIG_1_LEN,        SI446X_GLOBAL_CONFIG_1,
  SI446X_INT_CTL_ENABLE_4_LEN,       SI446X_INT_CTL_ENABLE_4,
  SI446X_PREAMBLE_LEN,               SI446X_PREAMBLE,
  SI446X_PKT_CRC_CONFIG_7_LEN,       SI446X_PKT_CRC_CONFIG_7,
  SI446X_PKT_LEN_5_LEN,              SI446X_PKT_LEN_5,
  SI446X_PKT_TX_FIELD_CONFIG_6_LEN,  SI446X_PKT_TX_FIELD_CONFIG_6,
  SI446X_PKT_RX_FIELD_CONFIG_10_LEN, SI446X_PKT_RX_FIELD_CONFIG_10,
  SI446X_MODEM_RSSI_LEN,             SI446X_MODEM_RSSI,
  SI446X_PKT_THRESH_LEN,             SI446X_PKT_THRESH,
  SI446X_PA_LEVEL_LEN,               SI446X_PA_LEVEL,
  0
};

#endif  /* __SI446X_CONFIG_DEVICE_H__ */
