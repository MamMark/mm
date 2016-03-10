/*
 * Copyright 2010, 2016 Eric B. Decker
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
 * Originally, we piggy-backed on the UCSI/SPI arbiter.  And explicitly
 * tweak the UCSI when the SD gets powered up/down.  However, this made
 * the driver cognizant of what h/w the SD is hanging off (ie. msp430
 * ucsi dependent).
 *
 * Mulitple clients are supported with  automatic power up, reset, and
 * power down when no further requests are pending.
 */


#ifndef SD_RESOURCE
#define SD_RESOURCE     "Sd.Resource"
#endif

generic configuration SD_ArbC() {
  provides {
    interface Resource;
    interface ResourceRequested;
    interface SDread;
    interface SDwrite;
    interface SDerase;
  }
}

implementation {
  enum {
    CLIENT_ID = unique(SD_RESOURCE),
  };

  components SD_ArbP;
  Resource                 = SD_ArbP.Resource[CLIENT_ID];
  ResourceRequested        = SD_ArbP.ResourceRequested[CLIENT_ID];

  components SDspC as SD;
  SDread  = SD.SDread[CLIENT_ID];
  SDwrite = SD.SDwrite[CLIENT_ID];
  SDerase = SD.SDerase[CLIENT_ID];
}
