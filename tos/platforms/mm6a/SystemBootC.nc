/*
 * Copyright (c) 2017 Eric B. Decker
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
 *
 * Sequence the bootup.  Components that should fire up when the
 * system is completely booted should wire to SystemBootC.Boot.
 *
 * 0) Check for Low Power
 *    low power -> start the low power boot chain
 *    ok power -> start the normal boot chain
 *
 * OK Power chain
 * 1) Bring up the SD/StreamStorage, FileSystem
 * 2) Bring up ImageManager (image = code image), needed by OW
 * 3) Invoke OverWatch (OW) to check for actions. (not NIB)
 * 4) Post Restart/Reboot record.  (mmSync)
 * 5) Bring up the GPS.  (GPS assumes SS is up)
 *
 * Low power chain
 * not yet defined.
 */

/*
 * Signals Boot.booted for normal power up
 */
configuration SystemBootC {
  provides interface Boot;
  provides interface Boot as BootLow;
  uses interface Init     as SoftwareInit;
}
implementation {
  components MainC;
  SoftwareInit = MainC.SoftwareInit;

  components PowerManagerC as PM;
  components FileSystemC   as FS;
  components ImageManagerC as IM;
  components OverWatchC    as OW;
  components DblkManagerC  as DM;
  components mmSyncC       as SYNC;
  components GPS0C         as GPS;

  PM.Boot -> MainC;                     // first check for power state

  /* Low Power Chain */
  BootLow = PM.LowPowerBoot;

  /* Normal Power Chain */
  FS.Boot   -> PM.OKPowerBoot;
  IM.Boot   -> FS.Booted;
  OW.Boot   -> IM.Booted;

  /*
   * Note: If OWT (OverWatch TinyOS) determines that it has something to
   * do it will set up and then exit without signalling OW.Booted.  This
   * will let the OWT functions do their thing.
   *
   * When OWT is finished, it will always reboot into a different operating
   * mode.
   *
   * If OWT isn't invoked then OW will signal Booted to let the normal
   * boot sequence to occur.
   */
  DM.Boot   -> OW.Booted;
  SYNC.Boot -> DM.Booted;

  /*
   * Logging to Data Area can't happen until after SYNC.
   * If Panic tries to put stuff into the Data Area (ie. Panic.warn)
   * it can't do this until after SYNC.
   */

  GPS.Boot  -> SYNC.Booted;
  Boot      =  GPS.Booted;
}
