/*
 * Copyright 2010, Eric B. Decker
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
 * SD_ArbC provides an provides an arbitrated interface to the SD.
 * Lives on SPI0, usciB0 on the 2618.
 *
 * supports multiple clients and handles automatic power up, reset,
 * and power down when no requests are pending.
 *
 * Power control is handled by SDspC/SDspP via SPI0_OwnerC which
 * wires the ResourceDefaultOwner.
 */

#include "msp430usci.h"

generic configuration SD_ArbC() {
  provides {

    interface Resource;

    interface SDread;
    interface SDwrite;
    interface SDerase;
  }
}

implementation {
  enum {
    CLIENT_ID = unique(MSP430_HPLUSCIB0_RESOURCE),
  };

  /*
   * SD_ArbC provides arbited access to the SD on usciB0.  Pwr
   * control is wired in SPI0_Owner (SDspC/P).
   */
  components Msp430UsciShareB0P as UsciShareP;
  Resource = UsciShareP.Resource[CLIENT_ID];

  components SDspC as SD;
  SDread  = SD.SDread[CLIENT_ID];
  SDwrite = SD.SDwrite[CLIENT_ID];
  SDerase = SD.SDerase[CLIENT_ID];
}
