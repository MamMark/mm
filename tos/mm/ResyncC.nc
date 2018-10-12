/**
 * Copyright (c) 2018 Eric B. Decker
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

configuration ResyncC {
  provides interface Resync[uint8_t cid];
}
implementation {
  enum {
    DMF_CID = unique("DblkMapFile.cid"),
  };

  components ResyncP;
  Resync = ResyncP;

  components new TimerMilliC();
  ResyncP.ResyncTimer -> TimerMilliC;

  components FileSystemC as FS;
  ResyncP.DMF -> FS.DblkFileMap[DMF_CID];

  components PanicC;
  ResyncP.Panic -> PanicC;
}
