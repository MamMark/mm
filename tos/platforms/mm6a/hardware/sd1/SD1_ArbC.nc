/*
 * Copyright (c) 2010, 2016-2017 Eric B. Decker
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


/*
 * SD1_ArbC pulls in SD1_ArbP which has the arbiter.  We can't pull ArbP
 * into ArbC because FcfsArbiterC is generic and needs to be a singleton.
 *
 * SD1C is the exported SD port wired to a particular SPI port and
 * connected to the actual driver.
 *
 * Wire ResourceDefaultOwner so the DefaultOwner handles power up/down.
 * When no clients are using the resource, the default owner gets it and
 * powers down the SD.
 */

#ifndef SD1_RESOURCE
#define SD1_RESOURCE     "SD1.Resource"
#endif

generic configuration SD1_ArbC() {
  provides {
    interface SDread;
    interface SDwrite;
    interface SDerase;

    interface Resource;
    interface ResourceRequested;
  }
}

implementation {
  enum {
    CLIENT_ID = unique(SD1_RESOURCE),
  };

  components SD1_ArbP as ArbP;
  components SD1C as SD;

  Resource                 = ArbP.Resource[CLIENT_ID];
  ResourceRequested        = ArbP.ResourceRequested[CLIENT_ID];

  SDread  = SD.SDread[CLIENT_ID];
  SDwrite = SD.SDwrite[CLIENT_ID];
  SDerase = SD.SDerase[CLIENT_ID];
}
