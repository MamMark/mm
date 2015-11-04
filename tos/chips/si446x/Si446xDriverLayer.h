/*
 * Copyright (c) 2015, Eric B. Decker
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 *
 * - Neither the name of the copyright holders nor the names of
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
 * Author: Eric B. Decker <cire831@gmail.com>
 */

#ifndef __SI446X_DRIVERLAYER_H__
#define __SI446X_DRIVERLAYER_H__

/*
 * default channel for setting FREQCTRL
 */
#ifndef SI446X_DEF_CHANNEL
#define SI446X_DEF_CHANNEL 0
#endif

#ifndef SI446X_DEF_RFPOWER
#define SI446X_DEF_RFPOWER 31
#endif

typedef union si446x_status {
  uint8_t value;
  struct {                              /* little endian */
    unsigned  rx_active    :1;
    unsigned  tx_active    :1;
    unsigned  dpu_l_active :1;
    unsigned  dpu_h_active :1;

    unsigned  exception_b  :1;
    unsigned  exception_a  :1;
    unsigned  rssi_valid   :1;
    unsigned  xosc_stable  :1;
  } f;
} si446x_status_t;

enum {
  SI446X_TX_PWR_MASK  = 0xFF,
  SI446X_CHANNEL_MASK = 0x1F,

  SI446X_TX_PWR_0     = 0x03,           // -18 dBm
  SI446X_TX_PWR_1     = 0x2C,           //  -7 dBm
  SI446X_TX_PWR_2     = 0x88,           //  -4 dBm
  SI446X_TX_PWR_3     = 0x81,           //  -2 dBm
  SI446X_TX_PWR_4     = 0x32,           //   0 dBm
  SI446X_TX_PWR_5     = 0x13,           //   1 dBm
  SI446X_TX_PWR_6     = 0xAB,           //   2 dBm
  SI446X_TX_PWR_7     = 0xF2,           //   3 dBm
  SI446X_TX_PWR_8     = 0xF7,           //   5 dBm
};


enum si446x_enums {
  SI446X_TIME_ACK_TURNAROUND = 7,                       // jiffies
  SI446X_TIME_VREN = 20,                                // jiffies
  SI446X_TIME_SYMBOL = 2,                               // 2 symbols / jiffy
  SI446X_BACKOFF_PERIOD = ( 20 / SI446X_TIME_SYMBOL ),  // symbols
  SI446X_MIN_BACKOFF = ( 20 / SI446X_TIME_SYMBOL ),     // platform specific?
  SI446X_ACK_WAIT_DELAY = 256,                          // jiffies
};


enum {
  SI446X_INVALID_TIMESTAMP  = 0x80000000L,
};


#endif // __SI446X_DRIVERLAYER_H__
