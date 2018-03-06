/**
 * @Copyright (c) 2017 Daniel J. Maltbie
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
 * @author Daniel J. Maltbie <dmaltbie@daloma.org>
 */

#include <Tagnet.h>

configuration DblkByteStorageC {
  provides {
    interface  TagnetAdapter<tagnet_file_bytes_t>  as DblkBytes;
    interface  TagnetAdapter<tagnet_dblk_note_t>   as DblkNote;
  }
}
implementation {
  components           PanicC, SystemBootC;
  components           FileSystemC as FS;
  components           DblkByteStorageP as DBS;

  DblkBytes          = DBS.DblkBytes;
  DblkNote           = DBS.DblkNote;
  DBS.Panic         -> PanicC;

  components           CollectC;
  DBS.Collect       -> CollectC;
  DBS.DMF           -> FS.DblkFileMap;
}
