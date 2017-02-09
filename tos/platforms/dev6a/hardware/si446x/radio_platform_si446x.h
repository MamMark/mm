/*
 * Copyright (c) 2016 Eric B. Decker
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
 *
 * This file pulls together any platform dependent configuration values
 * for a si446x radio.
 *
 * In particular, it exports most of the WDS generated static values
 * from radio_config_si446x.h as SI446X_WDS_CONFIG_BYTES.  This prevents
 * the WDS generated name space from bleeding into the driver.
 *
 * SI446X_RF_POWER_UP contains the value of TXCO which denotes whether
 * an external Xtal is connected to the radio chip.
 *
 * SI446X_RF_GPIO_CFG contains the values used to program the GPIO pins.
 * A given board (platform) will potentially have gpio pins connected to
 * a TX/RX switch and need to be programmed appropriately.
 */

#ifndef __RADIO_PLATFORM_SI446X_H__
#define __RADIO_PLATFORM_SI446X_H__

#define SI446X_CHIP 0x4463a

// #define SI446X_HW_CTS

/*
 * SI446X_RF_POWER_UP is a platform dependent define.  In particular, TXCO should be
 * set to 1 if we are using an external Xtal.  VERIFY   TODO.
 */
#define SI446X_RF_POWER_UP 0x02, 0x01, 0x00, 0x01, 0xC9, 0xC3, 0x80


/*
 * SI446X_RF_GPIO_CFG determines how the gpio pins are programmed.
 *
 * gp0: 0, gp1: cts, gp2: rx_state (33), gp3: tx_state (32)
 * gp2: 0, gp3: 1 -> Tx,   gp2: 1, gp3: 0 -> Rx
 */
#define SI446X_GPIO_PIN_CFG_LEN    8
#define SI446X_RF_GPIO_PIN_CFG     0x13, 2, 8, 33, 32, 0x00, 0x00, 0x00


/*
 * Export WDS values for Static WDS configuration
 * This keeps the name space from the WDS program inside this file.
 */
#define SI446X_WDS_CONFIG_BYTES { \
        0x06, RF_GLOBAL_XO_TUNE_2, \
        0x09, RF_SYNC_CONFIG_5, \
        0x10, RF_MODEM_MOD_TYPE_12, \
        0x05, RF_MODEM_FREQ_DEV_0_1, \
        0x0C, RF_MODEM_TX_RAMP_DELAY_8, \
        0x0D, RF_MODEM_BCR_OSR_1_9, \
        0x0B, RF_MODEM_AFC_GEAR_7, \
        0x05, RF_MODEM_AGC_CONTROL_1, \
        0x0D, RF_MODEM_AGC_WINDOW_SIZE_9, \
        0x0D, RF_MODEM_OOK_CNT1_9, \
        0x05, RF_MODEM_RSSI_CONTROL_1, \
        0x05, RF_MODEM_RSSI_COMP_1, \
        0x05, RF_MODEM_CLKGEN_BAND_1, \
        0x10, RF_MODEM_CHFLT_RX1_CHFLT_COE13_7_0_12, \
        0x10, RF_MODEM_CHFLT_RX1_CHFLT_COE1_7_0_12, \
        0x10, RF_MODEM_CHFLT_RX2_CHFLT_COE7_7_0_12, \
        0x08, RF_PA_MODE_4, \
        0x0B, RF_SYNTH_PFDCP_CPFF_7, \
        0x10, RF_MATCH_VALUE_1_12, \
        0x0C, RF_FREQ_CONTROL_INTE_8, \
        0x00 \
 }

#endif          // __RADIO_PLATFORM_SI446X_H__
