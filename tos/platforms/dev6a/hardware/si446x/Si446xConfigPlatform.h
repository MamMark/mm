#ifndef __SI446X_CONFIG_PLATFORM_H__
#define __SI446X_CONFIG_PLATFORM_H__

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

/*
 * <chip> refers to the exact chip being supported.  Looks like there
 * are too many behavioural differences between the 4463 and 4468.
 * So <chip> may be si44631B or si44682A.  Chip revs also seem to make
 * a significant difference. All operations performed as 4463 commands.
 *
 * Where we've identified definitions that do work across both chips, we
 * have kept the nomenclature of SI446X_...
 *
 * This file pulls together any platform dependent configuration values
 * for a <chip> radio.
 *
 * In particular, it exports most of the WDS generated static values
 * from radio_config_<chip>.h as <chip>_WDS_CONFIG_BYTES.  This prevents
 * the WDS generated name space from bleeding into the driver.
 *
 * SI446X_RF_POWER_UP contains the value of TXCO which denotes whether
 * an external Xtal is connected to the radio chip.
 * NOTE: Used explicitly by command in state machine
 *
 * SI446X_RF_GPIO_CFG contains the values used to program the GPIO pins.
 * A given board (platform) will potentially have gpio pins connected to
 * a TX/RX switch and need to be programmed appropriately.
 * NOTE: included in the si446x_device_config string list
 */

/* Select the chip type to modify si446x.h definitions
 */
#define SI446X_CHIP 0x44631B
#ifdef RPI_BUILD
#include "si446x.h"
#else
#include <si446x.h>
#endif

#define SI446X_HW_CTS

/*
 * SI446X_RF_POWER_UP
 *
 * Configure the oscillator frequency for 30 MHz
 * TXCO should be set to 1 if we are using an external Xtal.  VERIFY   TODO.
 */
#define SI446X_RF_POWER_UP 0x02, 0x01, 0x00, 0x01, 0xC9, 0xC3, 0x80

/*
 * SI446X_RF_GPIO_CFG
 *
 * Specify how the gpio pins are programmed.
 *
 * gp0: in_sleep (28),  asleep: gp0=0
 * gp1: cts(8), clear: gp1=1
 * gp2: rx_state (33), gp3: tx_state (32)
 *      Transmit: gp2=0, gp3=1
 *      Receive:  gp2=1, gp3=0
 */
#define SI446X_GPIO_PIN_CFG_LEN    8
#define SI446X_RF_GPIO_PIN_CFG     0x13, 28, 8, 33, 32, 0x00, 0x00, 0x00


#endif  /* __SI446X_CONFIG_PLATFORM_H__ */
