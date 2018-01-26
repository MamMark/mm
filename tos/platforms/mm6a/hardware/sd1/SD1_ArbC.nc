/*
 * Copyright (c) 2010, 2016-2017 Eric B. Decker
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
