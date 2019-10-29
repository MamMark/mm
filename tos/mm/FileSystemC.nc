/**
 * Copyright (c) 2017 Eric B. Decker
 * Copyright (c) 2010 Eric B. Decker, Carl W. Davis
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
 *          Carl W. Davis
 */

/*
 * Configuration wiring for FileSystem.  See FileSystemP for
 * more details on what FileSystem does.
 */

#include <fs_loc.h>

configuration FileSystemC {
  provides {
    interface Boot        as Booted;    /* out Booted signal */
    interface FileSystem  as FS;
    interface ByteMapFile as DblkFileMap[uint8_t cid];
    interface ByteMapFile as PanicFileMap;
  }
  uses interface Boot;			/* incoming signal */
}
implementation {
  components FileSystemP   as FS_P;
  components DblkMapFileP  as DMF;
  components PanicMapFileP as PMF;

  /* exports, imports */
  FS     = FS_P;
  Booted = FS_P;
  Boot   = FS_P;

  DblkFileMap  = DMF.DMF;
  PanicFileMap = PMF.PMF;

  components     SSWriteC;
  components new SD0_ArbC() as SD_FS;   /* filesystem   SD   */
  components new SD0_ArbC() as SD_DMF;  /* DblkMapFile  SD   */
  components new SD0_ArbC() as SD_PMF;  /* PanicMapFile SD   */
  components     SD0C       as SDsa;    /* StandAlone for FS */

  FS_P.SSW        -> SSWriteC;
  FS_P.SDResource -> SD_FS;
  FS_P.SDread     -> SD_FS;
  FS_P.SDerase    -> SD_FS;
  FS_P.SDsa       -> SDsa;

  PMF.SDResource    -> SD_PMF;
  PMF.SDread        -> SD_PMF;

  DMF.SDResource    -> SD_DMF;
  DMF.SDread        -> SD_DMF;

  DMF.SS            -> SSWriteC;

  components PanicC;
  FS_P.Panic -> PanicC;
  DMF.Panic         -> PanicC;
  PMF.Panic         -> PanicC;
  PMF.PanicManager  -> PanicC.PanicManager;

  components SystemBootC;
  PMF.Boot          -> SystemBootC.Boot;

  components OverWatchC, CollectC;
  FS_P.OverWatch    -> OverWatchC;
  FS_P.CollectEvent -> CollectC;
  DMF.OverWatch     -> OverWatchC;
  DMF.CollectEvent  -> CollectC;
  PMF.OverWatch     -> OverWatchC;
  PMF.CollectEvent  -> CollectC;
}
