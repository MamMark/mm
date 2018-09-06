/*
 * Copyright (c) 2018      Daniel J. Maltbie
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
 * Author: Daniel J. Maltbie <dmaltbie@daloma.org>
 *
 * Global Structure for collecting Si446x Radio Driver Statistics.
 */
#ifndef __SI446X_STATS_H__
#define __SI446X_STATS_H__

typedef struct si446x_stats {
  uint32_t                          rc_readys;
  uint32_t                          tx_packets;
  uint32_t                          tx_reports;
  uint32_t                          rx_packets;
  uint32_t                          rx_reports;

  uint16_t                          tx_timeouts;
  uint16_t                          tx_underruns;    // tx active, fifo underrun, oops

  uint16_t                          rx_bad_crcs;     /* active to crc_flush */
  uint16_t                          rx_timeouts;
  uint16_t                          rx_inv_syncs;
  uint16_t                          rx_errors;

  uint16_t                          rx_overruns;     // inbound overuns, hw
  uint16_t                          rx_active_overruns; // active fifo overrun
  uint16_t                          rx_crc_overruns;    // crc_flush fifo overrun

  uint16_t                          rx_crc_packet_rx;   // crc_flush packet_rx, weird

  uint16_t                          nops;
  uint16_t                          unshuts;
  uint8_t                           channel;         // current channel setting
  uint8_t                           tx_power;        // current power setting
  uint8_t                           tx_ff_index;     // msg offset for fifo write
  uint8_t                           rx_ff_index;     // msg offset for fifo read
  bool                              rc_signal;       // signal command complete
  bool                              tx_signal;       // signal transmit complete
  error_t                           tx_error;        // last tx error
  uint8_t                           send_tries;      // flag to track send msg retry
  uint32_t                          send_wait_time;  // send message time to wait
  uint32_t                          send_max_wait;   // max wait time to send
  uint8_t                           last_rssi;       // last received value
  uint8_t                           min_rssi;        // minimum received value
  uint8_t                           max_rssi;        // maximum received value
} si446x_stats_t;

#endif          //__SI446X_STATS_H__
