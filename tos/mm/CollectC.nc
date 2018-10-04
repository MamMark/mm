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
    interface Boot as EndOut;           /* out boot */
    interface Collect;
    interface CollectEvent;
    interface TagnetAdapter<uint32_t> as DblkLastRecNum;
    interface TagnetAdapter<uint32_t> as DblkLastRecOffset;
    interface TagnetAdapter<uint32_t> as DblkLastSyncOffset;
    interface TagnetAdapter<uint32_t> as DblkCommittedOffset;
    interface TagnetAdapter<uint32_t> as DblkResyncOffset;
  }
  uses {
    interface Boot;                     /* in  boot */
    interface Boot as EndIn;            /* in  boot */
  }
}

implementation {

  components MainC, SystemBootC, CollectP;
  MainC.SoftwareInit -> CollectP;
  CollectP.SysBoot   -> SystemBootC.Boot;

  Booted       = CollectP.Booted;       /* outgoing, Collect done   */
  EndOut       = CollectP.EndOut;       /* outgoing, end of SysBoot */

  Collect      = CollectP;
  CollectEvent = CollectP;

  Boot         = CollectP.Boot;         /* income start */
  EndIn        = CollectP.EndIn;        /* incoming end of SysBoot */

  DblkLastRecNum      = CollectP.DblkLastRecNum;
  DblkLastRecOffset   = CollectP.DblkLastRecOffset;
  DblkLastSyncOffset  = CollectP.DblkLastSyncOffset;
  DblkCommittedOffset = CollectP.DblkCommittedOffset;
  DblkResyncOffset    = CollectP.DblkResyncOffset;

  components new TimerMilliC() as SyncTimerC;
  CollectP.SyncTimer -> SyncTimerC;

  components new TimerMilliC() as ResyncTimerC;
  CollectP.ResyncTimer -> ResyncTimerC;

  components FileSystemC as FS;
  CollectP.DMF -> FS.DblkFileMap;

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
