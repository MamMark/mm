/*
 * Copyright (c) 2020, Eric B. Decker
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

configuration Dock0C {
  provides {
    interface MsgReceive;
    interface MsgTransmit;

    /* for debugging only, be careful */
    interface DockCommHardware as HW;
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
  components HplDock0C;
  HW = HplDock0C;

  components DockDriverP;
  DockDriverP.HW       -> HplDock0C;

  components PlatformC, PanicC;
  DockDriverP.Panic    -> PanicC;
  DockDriverP.Platform -> PlatformC;

  /* and wire in the Protocol Handler */
  components DockProtoP, MsgBufP;
  DockDriverP.DockProto -> DockProtoP;

  DockProtoP.MsgBuf  -> MsgBufP;
  DockProtoP.Panic   -> PanicC;

  /* Buffer Slicing (MsgBuf) */
  MainC.SoftwareInit -> MsgBufP;
  MsgBufP.Rtc        -> PlatformC;
  MsgBufP.Panic      -> PanicC;

  MsgReceive  = MsgBufP;
  MsgTransmit = DockDriverP;

#ifdef notdef
  components TraceC;
  Gsd4eUP.Trace -> TraceC;
#endif
}
