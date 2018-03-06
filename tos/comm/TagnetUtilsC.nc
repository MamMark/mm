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

/**
 * This configuration combines several modules providing interfaces
 * to access a Tagnet Message into a single component.
 *<p>
 * Typically the interfaces provided by this configuration are used
 * within the Tagnet stack itself. But there are a few special cases
 * where direct access to the message is required outside of the stack.
 * Otherwise, the stack provides alternative interfaces for adapting
 * network access to system wide data of standard C types.
 *</p>
 *<p>
This includes the following modules:
 *</p>
 *<dl>
 *   <dt>TagnetHeaderP</dt> <dd>module for manipulating the header in
 *     a Tagnet message</dd>
 *   <dt>TagnetNameP</dt> <dd>module for manipulating the name in a
 *     Tagnet message</dd>
 *   <dt>TagnetPayloadP</dt> <dd>module for manipulating the payload
 *     in a Tagnet message</dd>
 *   <dt>TagnetTlvP</dt> <dd>module for manipulating Tagnet TLVs. Found
 *     in the name and payload fields of Tagnet message</dd>
 *</dl>
 */

configuration TagnetUtilsC {
  provides interface TagnetName;
  provides interface TagnetHeader;
  provides interface TagnetPayload;
  provides interface TagnetTLV;
}
implementation {
  components     TagnetNameP;
  components     TagnetHeaderP;
  components     TagnetPayloadP;
  components     TagnetTlvP;
  components     PanicC;

  TagnetName            =  TagnetNameP;
  TagnetHeader          =  TagnetHeaderP;
  TagnetPayload         =  TagnetPayloadP;
  TagnetTLV             =  TagnetTlvP;

  TagnetNameP.THdr      -> TagnetHeaderP;
  TagnetNameP.TTLV      -> TagnetTlvP;

  TagnetPayloadP.THdr   -> TagnetHeaderP;
  TagnetPayloadP.TTLV   -> TagnetTlvP;

  TagnetTlvP.Panic      -> PanicC;
}
