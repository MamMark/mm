/**
 * Copyright (c) 2017 Eric B. Decker
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
 * @author Eric B. Decker
 * @date: August 20, 2017
 *
 * Configuration wiring for DblkManager.  See DblkManagerP for more details
 * on what DblkManager does.
 */

configuration DblkManagerC {
  provides {
    interface Boot        as Booted;    /* out Booted signal */
    interface DblkManager as DM;
  }
  uses interface Boot;			/* incoming signal */
}
implementation {
  components DblkManagerP  as DMP;

  /* exports, imports */
  DM     = DMP;
  Booted = DMP;
  Boot   = DMP;

  components new SD0_ArbC() as SD, SSWriteC;
  components FileSystemC, SD0C;

  DMP.SSW        -> SSWriteC;
  DMP.SDResource -> SD;
  DMP.SDread     -> SD;
  DMP.SDraw      -> SD0C;
  DMP.FileSystem -> FileSystemC;

  components PanicC;
  DMP.Panic -> PanicC;
}
