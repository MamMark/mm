/**
 * Copyright (c) 2008, 2017-2018 Eric B. Decker
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

configuration CollectC {
  provides {
    interface Boot as Booted;           /* out boot */
    interface Collect;
    interface CollectEvent;
    interface TagnetAdapter<uint32_t> as DblkLastRecNum;
    interface TagnetAdapter<uint32_t> as DblkLastRecOffset;
    interface TagnetAdapter<uint32_t> as DblkLastSyncOffset;
    interface TagnetAdapter<uint32_t> as DblkCommittedOffset;
  }
  uses     interface Boot;              /* in  boot */
}

implementation {

  components MainC, SystemBootC, CollectP;
  MainC.SoftwareInit -> CollectP;
  CollectP.SysBoot   -> SystemBootC.Boot;

  Booted       = CollectP;
  Collect      = CollectP;
  CollectEvent = CollectP;
  Boot         = CollectP.Boot;

  DblkLastRecNum      = CollectP.DblkLastRecNum;
  DblkLastRecOffset   = CollectP.DblkLastRecOffset;
  DblkLastSyncOffset  = CollectP.DblkLastSyncOffset;
  DblkCommittedOffset = CollectP.DblkCommittedOffset;

  components new TimerMilliC() as SyncTimerC;
  CollectP.SyncTimer -> SyncTimerC;

  components OverWatchC;
  CollectP.OverWatch -> OverWatchC;

  components DblkManagerC;
  CollectP.DblkManager -> DblkManagerC;

  components SSWriteC;
  CollectP.SSW -> SSWriteC;
  CollectP.SS  -> SSWriteC;

  components PanicC;
  CollectP.Panic -> PanicC;

  components PlatformC;
  CollectP.Rtc       -> PlatformC;
  CollectP.SysReboot -> PlatformC;
}
