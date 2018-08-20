/*
 * Copyright (c) 2018 Eric B. Decker
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
 * PwrGpsMems - control Gps/Mems pwr rail
 */

#include <platform_pin_defs.h>

module PwrGpsMemsP {
  provides {
    interface Init;
    interface PwrReg;
  }
}
implementation {
  /*
   * only state we maintain is refcount.  If refcount is non-zero
   * the switch is on.
   */
  uint8_t m_refcount;

  void mems0_port_enable() {
    atomic {
      MEMS0_ACCEL_CSN     = 1;          /* deselect */
      MEMS0_ACCEL_CSN_DIR = 1;          /* switch CSN to output */
      MEMS0_GYRO_CSN      = 1;
      MEMS0_GYRO_CSN_DIR  = 1;
      MEMS0_MAG_CSN       = 1;
      MEMS0_MAG_CSN_DIR   = 1;
      MEMS0_SCLK_SEL0     = 1;          /* kick over to the spi module */
      MEMS0_SIMO_SEL0     = 1;          /* module mode */
      MEMS0_SOMI_SEL0     = 1;
    }
  }

  void mems0_port_disable() {
    atomic {
      MEMS0_SCLK_SEL0     = 0;          /* force to port mode */
      MEMS0_SIMO_SEL0     = 0;
      MEMS0_SOMI_SEL0     = 0;
      MEMS0_ACCEL_CSN_DIR = 0;          /* switch CSN to input */
      MEMS0_GYRO_CSN_DIR  = 0;
      MEMS0_MAG_CSN_DIR   = 0;
      MEMS0_SCLK_SEL0     = 0;
      MEMS0_SIMO_SEL0     = 0;
      MEMS0_SOMI_SEL0     = 0;
    }
  }

  command error_t Init.init() {
    /* If gps/mems power is on, signal pwrOn and set the refcount to 1. */
    if (GPS_MEMS_1V8_EN) {
      mems0_port_enable();
      signal PwrReg.pwrOn();
    }
    return SUCCESS;
  }

  async command error_t PwrReg.pwrReq() {
    atomic {
      GPS_MEMS_1V8_EN = 1;                /* turn on always */
      mems0_port_enable();
      signal PwrReg.pwrOn();
    }
    return EALREADY;                    /* no delay */
  }


  /* query power state */
  async command bool PwrReg.isPowered() {
    return GPS_MEMS_1V8_EN;
  }


  /* release does nothing.  to turn off pwr use forceOff() */
  async command void PwrReg.pwrRel()   { }


  async command void PwrReg.forceOff() {
    atomic {
      mems0_port_disable();
      signal PwrReg.pwrOff();
      GPS_MEMS_1V8_EN = 0;              /* turn off */
    }
  }

  default async event void PwrReg.pwrOn()  { }
  default async event void PwrReg.pwrOff() { }
}
