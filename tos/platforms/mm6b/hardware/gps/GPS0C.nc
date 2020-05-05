/*
 * Copyright (c) 2020,     Eric B. Decker
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
    interface MsgReceive;
    interface MsgTransmit;
    interface PwrReg as GPSPwr;

    /* for debugging only, be careful */
    interface ubloxHardware as HW;
  }
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
  HW     = HplGPS0C;
  GPSPwr = HplGPS0C;

  /* low level driver, start there */
  components ubloxZoeUP as GPSDriverP;
  components new TimerMilliC() as GPSTxTimer;
  components new TimerMilliC() as GPSRxTimer;
  components new TimerMilliC() as GPSRxErrorTimer;
  components     LocalTimeMilliC;
  components     CollectC;
  components     OverWatchC;

  GPSControl = GPSDriverP;

  GPSDriverP.HW        -> HplGPS0C;
  GPSDriverP.GPSPwr    -> HplGPS0C;
  GPSDriverP.OverWatch -> OverWatchC;

  GPSDriverP.GPSTxTimer      -> GPSTxTimer;
  GPSDriverP.GPSRxTimer      -> GPSRxTimer;
  GPSDriverP.GPSRxErrorTimer -> GPSRxErrorTimer;
  GPSDriverP.LocalTime       -> LocalTimeMilliC;
  GPSDriverP.Collect         -> CollectC;
  GPSDriverP.CollectEvent    -> CollectC;

  components PlatformC, PanicC;
  GPSDriverP.Panic    -> PanicC;
  GPSDriverP.Platform -> PlatformC;

  /* and wire in the Protocol Handler */
  components ubxProtoP as GPSProtoP, MsgBufP;
  GPSDriverP.ubxProto  -> GPSProtoP;

  GPSProtoP.MsgBuf     -> MsgBufP;
  GPSProtoP.Collect    -> CollectC;
  GPSProtoP.Panic      -> PanicC;

  /* Buffer Slicing (MsgBuf) */
  MainC.SoftwareInit -> MsgBufP;
  MsgBufP.Rtc        -> PlatformC;
  MsgBufP.Panic      -> PanicC;

  MsgReceive  = MsgBufP;
  MsgTransmit = GPSDriverP;

#ifdef notdef
  components TraceC;
  GPSDriverP.Trace -> TraceC;
#endif
}
