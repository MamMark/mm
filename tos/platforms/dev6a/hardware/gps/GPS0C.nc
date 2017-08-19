/*
 * Copyright (c) 2017 Eric B. Decker, Daniel Maltbie
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
 * @author Eric B. Decker <cire831@gmail.com>
 * @author Daniel J. Maltbie <dmaltbie@daloma.org>
 */

configuration GPS0C {
  provides {
    interface GPSState;
    interface GPSReceive;
    interface GPSTransmit;
    interface Boot as GPSBoot;

    /* for debugging only, be careful */
    interface Gsd4eUHardware as HW;
  }
  uses interface Boot;
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
  components     LocalTimeMilliC;
  components     CollectC;

  GPSState = Gsd4eUP;
  Boot     = Gsd4eUP.Boot;
  GPSBoot  = Gsd4eUP.GPSBoot;

  Gsd4eUP.HW -> HplGPS0C;

  Gsd4eUP.GPSTxTimer -> GPSTxTimer;
  Gsd4eUP.GPSRxTimer -> GPSRxTimer;
  Gsd4eUP.LocalTime  -> LocalTimeMilliC;
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

  GPSReceive = GPSMsgBufP;
  GPSTransmit = Gsd4eUP;

#ifdef notdef
  components TraceC;
  Gsd4eUP.Trace -> TraceC;
#endif
}
