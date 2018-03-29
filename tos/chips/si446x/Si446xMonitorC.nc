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

configuration Si446xMonitorC {
  provides {
    interface  TagnetAdapter<message_t>  as  RadioRSSI;
    interface  TagnetAdapter<message_t>  as  RadioTxPower;
  }
}
implementation {
  components           Si446xMonitorP as MP;
  components           Si446xDriverLayerC;
  components           TagnetUtilsC;

  RadioRSSI          = MP.RadioRSSI;
  MP.PacketRSSI     -> Si446xDriverLayerC.PacketRSSI;

  RadioTxPower       = MP.RadioTxPower;
  MP.PacketTransmitPower -> Si446xDriverLayerC.PacketTransmitPower;

  MP.THdr           ->  TagnetUtilsC;
  MP.TPload         ->  TagnetUtilsC;
  MP.TTLV           ->  TagnetUtilsC;
}
