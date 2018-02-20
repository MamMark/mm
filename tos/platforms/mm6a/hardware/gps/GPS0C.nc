/*
 * Copyright (c) 2017-2018 Eric B. Decker, Daniel Maltbie
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
 *          Daniel J. Maltbie <dmaltbie@daloma.org>
 */

configuration GPS0C {
  provides {
    interface GPSControl;
    interface GPSReceive;
    interface GPSTransmit;
    interface Boot           as Booted; /* out boot */

    /* for debugging only, be careful */
    interface Gsd4eUHardware as HW;
  }
  uses interface Boot;                  /* in boot */
}

implementation {
  components MainC;

  /*
   * HW is a singleton interface (ie. non-generic).  If you wire this
   * twice, all events are fanned out.  Be careful when you do this.
   * ie.  TestGps used HW to muck with the h/w.  And it has empty
   * events to handle the fan out.
   */
  components HplGPS0C;
  HW = HplGPS0C;

  /* low level driver, start there */
  components Gsd4eUP;
  components new TimerMilliC() as GPSTxTimer;
  components new TimerMilliC() as GPSRxTimer;
  components new TimerMilliC() as GPSRxErrorTimer;
  components     LocalTimeMilliC;
  components     CollectC;

  GPSControl   = Gsd4eUP;

  Boot         = Gsd4eUP.Boot;
  Booted       = Gsd4eUP.Booted;

  Gsd4eUP.HW  -> HplGPS0C;

  Gsd4eUP.GPSTxTimer -> GPSTxTimer;
  Gsd4eUP.GPSRxTimer -> GPSRxTimer;
  Gsd4eUP.GPSRxErrorTimer -> GPSRxErrorTimer;
  Gsd4eUP.LocalTime  -> LocalTimeMilliC;
  Gsd4eUP.Collect      -> CollectC;
  Gsd4eUP.CollectEvent -> CollectC;

  components PlatformC, PanicC;
  Gsd4eUP.Panic    -> PanicC;
  Gsd4eUP.Platform -> PlatformC;

  /* and wire in the Protocol Handler */
  components SirfBinP, GPSMsgBufP;
  Gsd4eUP.SirfProto  -> SirfBinP;
  SirfBinP.GPSBuffer -> GPSMsgBufP;
  SirfBinP.Panic     -> PanicC;

  /* Buffer Slicing (MsgBuf) */
  MainC.SoftwareInit -> GPSMsgBufP;
  GPSMsgBufP.LocalTime -> LocalTimeMilliC;
  GPSMsgBufP.Panic -> PanicC;

  GPSReceive  = GPSMsgBufP;
  GPSTransmit = Gsd4eUP;

#ifdef notdef
  components TraceC;
  Gsd4eUP.Trace -> TraceC;
#endif
}
