#ifndef __SI446X_CONFIG_PLATFORM_H__
#define __SI446X_CONFIG_PLATFORM_H__

/*
 * Copyright (c) 2016-2018 Eric B. Decker, Daniel J. Maltbie
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
 *          Daniel J. Maltbie <dmaltbie@daloma.com>
 *
 * Author: Eric B. Decker
 * Date: 1/15/2016
 * Author: Daniel J. Maltbie <dmaltbie@daloma.org>
 * Date: 5/20/2017
 */

/*
 * <chip> refers to the exact chip being supported.  Looks like there
 * are too many behavioural differences between the 4463 and 4468.
 * So <chip> may be si44631B or si44682A.  Chip revs also seem to make
 * a significant difference. All operations performed as 4463 commands.
 *
 * Some features that we want to use only work with 4468, so have not
 * fully tested backwards compatibility (such as preamble sense mode
 * uses radio state 9, called 'idle'.
 *
 * Where we've identified definitions that do work across both chips, we
 * have kept the nomenclature of SI446X_...
 *
 * This file pulls together any platform dependent configuration values
 * for a <chip> radio.
 *
 * In particular, it exports the WDS generated static values from
 * radio_config_<chip>.h as <chip>_WDS_CONFIG_BYTES.  This prevents the
 * WDS generated name space from bleeding into the driver.
 *
 * SI446X_RF_GPIO_CFG contains the values used to program the GPIO pins.
 * A given board (platform) will potentially have gpio pins connected to
 * a TX/RX switch and need to be programmed appropriately. A CTS hardware
 * signal is also provided by a GPIO. For debugging purposes, the sleep
 * state is provided as well.
 * NOTE: included in the si446x_device_config string list
 */

/* Select the chip type to modify si446x.h definitions
 */
#define SI446X_CHIP 0x44682A
#include "si446x.h"

//#define SI446X_HW_CTS

/*
 * SI446X_RF_GPIO_CFG
 *
 * Specify how the gpio pins are programmed.
 *
 * gp0: in_sleep (28),  asleep: gp0=0
 * gp1: cts(8), clear: gp1=1
 * gp2: rx_state (33), gp3: tx_state (32)   NOTE: OPPOSITE OF PROTO BOARD
 *      Transmit: gp2=0, gp3=1
 *      Receive:  gp2=1, gp3=0
 *      NIRQ, SDO, GEN_CONFIG =0
 */
#define SI446X_GPIO_PIN_CFG_LEN    8
#define SI446X_RF_GPIO_PIN_CFG     SI446X_CMD_GPIO_PIN_CFG, SI446X_GPIO_IN_SLEEP, SI446X_GPIO_CTS, SI446X_GPIO_RX_STATE, SI446X_GPIO_TX_STATE, 0x00, 0x00, 0x00


#endif  /* __SI446X_CONFIG_PLATFORM_H__ */
