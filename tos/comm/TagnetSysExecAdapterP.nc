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

generic configuration TagnetSysExecAdapterP (int my_id) @safe() {
  uses interface     TagnetMessage  as  Super;
  uses interface     TagnetSysExecAdapter as Adapter;
}
implementation {
  components new TagnetSysExecAdapterImplP(my_id) as Element;
  components     TagnetUtilsC;

  Super           =  Element.Super;
  Element.TName  -> TagnetUtilsC;
  Element.THdr   -> TagnetUtilsC;
  Element.TPload -> TagnetUtilsC;
  Element.TTLV   -> TagnetUtilsC;
  Adapter         = Element.Adapter;
}
