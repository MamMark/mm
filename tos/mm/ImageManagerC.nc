/**
 * Copyright (c) 2017 Eric B. Decker, Miles Maltbie
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
 *          Miles Maltbie <milesmaltbie@gmail.com>
 */

/*
 * Configuration wiring for ImageManager.  See ImageManagerP for more
 * details on what ImageManager does.
 */

#include <image_mgr.h>

configuration ImageManagerC {
  provides {
    interface  Boot            as Booted;   /* out Booted signal */
    interface  ImageManager    as IM[uint8_t cid];
    interface ImageManagerData as IMD;
  }
  uses interface Boot;			/* incoming signal */
}
implementation {
  components ImageManagerP as IM_P;
  IM     = IM_P;
  IMD    = IM_P;
  Booted = IM_P;
  Boot   = IM_P;

  components FileSystemC as FS;
  IM_P.FS -> FS;

  components new SD0_ArbC() as SD;
  IM_P.SDResource -> SD;
  IM_P.SDread     -> SD;
  IM_P.SDwrite    -> SD;

  components ChecksumM;
  IM_P.Checksum -> ChecksumM;

  components CollectC;
  IM_P.CollectEvent -> CollectC;

  components PlatformC;
  IM_P.Platform -> PlatformC;

  components PanicC;
  IM_P.Panic -> PanicC;

  components SD0C, SSWriteC;
  IM_P.SDraw -> SD0C;
}
