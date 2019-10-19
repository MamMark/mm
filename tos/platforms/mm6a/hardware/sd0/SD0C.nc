/*
 * Copyright (c) 2010, 2016-2017 Eric B. Decker, Carl Davis, Daniel Maltbie
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
 *          Carl Davis
 *          Daniel J. Maltbie <dmaltbie@daloma.com>
 */

/*
 * SDnC instantiates the driver SDsp, (SD, split phase, event driven) and
 * connects it to the hardware port for the platform.
 *
 * read, write, and erase are for clients.  SDsa is SD stand alone which
 * is used if the system crashes/panics.
 *
 * SD_Arb provides an arbitrated interface for clients.  The port the
 * hardware is attached to is specified via HplSDnC (Hardware presentation
 * layer, SD, unit n).  ResourceDefaultOwner (RDO) from the Arbiter must be
 * wired into RDO of the driver.  RDO is responsible for powering up and
 * down the SD.  The SD is powered down when no clients are using it.
 */

configuration SD0C {
  provides {
    interface SDread[uint8_t cid];
    interface SDwrite[uint8_t cid];
    interface SDerase[uint8_t cid];
    interface SDsa;
    interface SDraw;
  }
  uses interface ResourceDefaultOwner;          /* power control */
}

implementation {
  components new SDspP() as SDdvrP;

  SDread   = SDdvrP;
  SDwrite  = SDdvrP;
  SDerase  = SDdvrP;
  SDsa     = SDdvrP;
  SDraw    = SDdvrP;

  ResourceDefaultOwner = SDdvrP;

  components MainC, McuSleepC;
  MainC.SoftwareInit -> SDdvrP;
  SDdvrP.McuPowerOverride <- McuSleepC;

  components PanicC;
  SDdvrP.Panic -> PanicC;

  components new TimerMilliC() as SDTimer;
  SDdvrP.SDtimer -> SDTimer;

  components CollectC;
  SDdvrP.CollectEvent -> CollectC;
  SDdvrP.Collect      -> CollectC;

  components HplSD0C as HW;
  SDdvrP.HW -> HW;

  components LocalTimeMilliC;
  SDdvrP.lt -> LocalTimeMilliC;

  components PlatformC;
  SDdvrP.Platform    -> PlatformC;
}
