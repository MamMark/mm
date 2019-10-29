/**
 * Copyright @ 2008, 2010, 2017 Eric B. Decker
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
 * Configuration wiring for stream storage write (SSWrite).  See
 * SSWriteP for more details on how stream storage works.
 *
 * StreamStorageWrite is split phase and interfaces to a split phase
 * SD mass storage driver.
 */

#include "stream_storage.h"

configuration SSWriteC {
  provides {
    interface SSWrite       as SSW;
    interface StreamStorage as SS;
  }
}

implementation {
  components SSWriteP as SSW_P, MainC;
  SSW = SSW_P;
  SS  = SSW_P;
  MainC.SoftwareInit -> SSW_P;

  components new SD0_ArbC() as SD;
  components SD0C;
  SSW_P.SDResource -> SD;
  SSW_P.SDwrite    -> SD;
  SSW_P.SDsa       -> SD0C;

  components PanicC, LocalTimeMilliC;
  SSW_P.Panic      -> PanicC;
  SSW_P.LocalTime  -> LocalTimeMilliC;

  components TraceC, CollectC;
  SSW_P.Trace        -> TraceC;
  SSW_P.CollectEvent -> CollectC;
  SSW_P.Collect      -> CollectC;

  components DblkManagerC;
  SSW_P.DblkManager -> DblkManagerC;

  components OverWatchC;
  SSW_P.OverWatch    -> OverWatchC;
  SSW_P.CollectEvent -> CollectC;
}
