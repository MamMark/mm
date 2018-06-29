/*
 * Copyright (c) 2017-2018 Eric B. Decker
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
 * 4) Post Restart/Reboot record.  (Collect)
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

  components CoreTimeC     as CT;
  components PowerManagerC as PM;
  components FileSystemC   as FS;
  components ImageManagerC as IM;
  components OverWatchC    as OW;
  components DblkManagerC  as DM;
  components CollectC      as SYNC;

  CT.Boot -> MainC;                     // first start DCO sync
  PM.Boot -> CT.Booted;                 // next check power state

  /* Low Power Chain */
  BootLow = PM.LowPowerBoot;

  /* Normal Power Chain */
  FS.Boot   -> PM.OKPowerBoot;
  IM.Boot   -> FS.Booted;
  OW.Boot   -> IM.Booted;               /* OWT */

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
  Boot      =  SYNC.Booted;
}
