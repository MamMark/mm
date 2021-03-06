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

#include "TagnetTLV.h"

generic configuration TagnetNameElementP (int my_id, char uq_id[]) {
  uses interface     TagnetMessage  as  Super;
  provides interface TagnetMessage  as  Sub[uint8_t id];
}
implementation {
  components new TagnetNameElementImplP(my_id, uq_id) as element;
  components     TagnetUtilsC;

  Super           =  element.Super;
  Sub             =  element.Sub;
  element.TName  -> TagnetUtilsC;
  element.THdr   -> TagnetUtilsC;
  element.TPload -> TagnetUtilsC;
  element.TTLV    -> TagnetUtilsC;
}
