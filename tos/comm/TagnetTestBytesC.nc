/**
 * @Copyright (c) 2017, 2018 Daniel J. Maltbie
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

configuration TagnetTestBytesC {
  provides {
    interface  TagnetAdapter<tagnet_file_bytes_t>  as TestZeroBytes;
    interface  TagnetAdapter<tagnet_file_bytes_t>  as TestOnesBytes;
    interface  TagnetAdapter<tagnet_file_bytes_t>  as TestEchoBytes;
    interface  TagnetAdapter<tagnet_file_bytes_t>  as TestDropBytes;
  }
}
implementation {
  components           PanicC, SystemBootC;
  components           TagnetTestBytesP as TBS;

  TestZeroBytes      = TBS.TestZeroBytes;
  TestOnesBytes      = TBS.TestOnesBytes;
  TestEchoBytes      = TBS.TestEchoBytes;
  TestDropBytes      = TBS.TestDropBytes;
  TBS.Boot          -> SystemBootC.Boot;
  TBS.Panic         -> PanicC;
}
