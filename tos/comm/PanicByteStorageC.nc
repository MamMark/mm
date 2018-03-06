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

configuration PanicByteStorageC {
  provides {
    interface  TagnetAdapter<tagnet_file_bytes_t>  as PanicBytes;
  }
}
implementation {
  components           PanicC, SystemBootC;
  components           FileSystemC as FS;
  components           PanicByteStorageP  as PBS;

  PanicBytes         = PBS.PanicBytes;
  PBS.ByteMapFile   -> FS.PanicFileMap;
  PBS.Panic         -> PanicC;

}
