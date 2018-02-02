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
    interface Boot       as Booted;     /* out Booted signal */
    interface FileSystem as FS;
  }
  uses interface Boot;			/* incoming signal */
}
implementation {
  components FileSystemP as FS_P;

  /* exports, imports */
  FS     = FS_P;
  Booted = FS_P;
  Boot   = FS_P;

  components new SD0_ArbC() as SD, SSWriteC;
  components     SD0C       as SDsa;

  FS_P.SSW        -> SSWriteC;
  FS_P.SDResource -> SD;
  FS_P.SDread     -> SD;
  FS_P.SDerase    -> SD;

  FS_P.SDsa       -> SDsa;

  components PanicC;
  FS_P.Panic -> PanicC;
}
