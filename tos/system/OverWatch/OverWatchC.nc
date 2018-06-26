/**
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
 * @author Eric B. Decker <cire831@gmail.com>
 *
 * Configuration wiring for OverWatch.  See OverWatchP for more details on
 * what OverWatch does.
 */

#include <overwatch.h>

configuration OverWatchC {
  provides {
    interface Boot as Booted;		/* out Booted signal */
    interface OverWatch as OW;
  }
  uses interface Boot;			/* incoming signal */
}

implementation {
  components OverWatchP as OW_P;
  OW     = OW_P;
  Booted = OW_P;
  Boot   = OW_P;

  components SD0C, SSWriteC;
  OW_P.SSW  -> SSWriteC;
  OW_P.SDsa -> SD0C;

  components ChecksumM;
  components ImageManagerC as IM_C;
  components OverWatchHardwareM as OWHW_M;
  OW_P.Checksum -> ChecksumM;
  OW_P.OWhw     -> OWHW_M;
  OW_P.IM       -> IM_C.IM[unique("image_manager_clients")];
  OW_P.IMD      -> IM_C;

  components CollectC;
  components LocalTimeMilliC;
  OW_P.LocalTime    -> LocalTimeMilliC;
  OW_P.CollectEvent -> CollectC;

  components PlatformC;
  OWHW_M.SysReboot -> PlatformC;
  OW_P.Rtc         -> PlatformC;
  OW_P.Platform    -> PlatformC;
}
