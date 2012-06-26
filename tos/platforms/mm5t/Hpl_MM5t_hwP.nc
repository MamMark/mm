/*
 * Copyright (c) 2012 Eric B. Decker
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
 */

/**
 * The Hpl_MM5t_hw interface exports low-level access to control registers
 * of the mammark h/w.
 *
 * MM5t hardware for early debugging.   MM5t corresponds to the msp430
 * eval board.
 *
 * @author Eric B. Decker
 */

#include "hardware.h"
#include "mm5tPortRegs.h"

module Hpl_MM5t_hwP {
  provides interface Hpl_MM5t_hw as HW;
}

implementation {
  async command void HW.gps_set_on_off() {
    ORG_GPS_SET_ONOFF;
  }

  async command void HW.gps_clr_on_off() {
    ORG_GPS_CLR_ONOFF;
  }

  async command void HW.gps_set_cs() {
    ORG_GPS_CSN = 0;
  }

  async command void HW.gps_clr_cs() {
    ORG_GPS_CSN = 1;
  }

  async command void HW.gps_set_reset() {
    ORG_GPS_RESET;
  }

  async command void HW.gps_clr_reset() {
    ORG_GPS_UNRESET;
  }

  async command bool HW.gps_awake() {
    return ORG_GPS_WAKEUP;
  }
}
