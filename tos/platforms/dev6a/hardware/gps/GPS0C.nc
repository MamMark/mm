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
    interface StdControl as GPSControl;
    interface Boot as GPSBoot;
    interface GPSReceive;
    interface Gsd4eUHardware as HW; // !!! for debugging only, be careful
  }
  uses interface Boot;
}

implementation {
  components MainC, Gsd4eUP;
  MainC.SoftwareInit -> Gsd4eUP;

  GPSControl = Gsd4eUP;
  GPSBoot = Gsd4eUP;
  Boot = Gsd4eUP.Boot;

  components Gsd4eUActP, GPSMsgBufP, PlatformC;
  Gsd4eUP.Act -> Gsd4eUActP;
  Gsd4eUActP.Platform -> PlatformC;
  Gsd4eUActP.GPSBuffer -> GPSMsgBufP;
  MainC.SoftwareInit -> GPSMsgBufP;
  GPSReceive = GPSMsgBufP;

  components HplGPS0C;
  Gsd4eUActP.HW -> HplGPS0C;
  HW = HplGPS0C;  // !!! wired twice, be careful to share this singleton interface

  components LocalTimeMilliC;
  Gsd4eUP.LocalTime -> LocalTimeMilliC;

  components new TimerMilliC() as GPSRxTimer;
  Gsd4eUP.GPSTxTimer -> GPSTxTimer;

  components new TimerMilliC() as GPSTxTimer;
  Gsd4eUP.GPSRxTimer -> GPSRxTimer;

  components PanicC;
  Gsd4eUP.Panic -> PanicC;
  Gsd4eUActP.Panic -> PanicC;
  GPSMsgBufP.Panic -> PanicC;

  components TraceC;
  Gsd4eUP.Trace -> TraceC;

#ifdef notdef
  components CollectC;
  Gsd4eUP.LogEvent -> CollectC;
#endif
}
