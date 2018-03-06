/**
 * @Copyright (c) 2016 Dan Maltbie
 * All right reserved.
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

configuration TagnetParseC {
  uses interface NameSpanner as Root;
}
implements {
  const byte TN_POLL_TLV[] = 1,3,'tag';
  const byte TN_POLL_TLV[] = 1,4,'poll';
  const byte TN_POLLNID_TLV[] = 5,6,'0xDEADBE';
  const byte TN_POLL_EV_TLV[] = 1,2,'ev';

  components new TagNetParseNameP(TN_TAG_TLV, UQ_TN_NAME_TAG, 'help string') as TagVx;
  components new TagNetParseNameP(TN_POLL_TLV, UQ_TN_NAME_POLL, 'help string') as PollVx;
  components new TagNetParseNameP(TN_POLL_TLV, UQ_TN_NAME_POLLNID, 'help string') as PollNidVx;
  components new TagNetAccessNameP(TN_POLL_TLV, UQ_TN_NAME_POLLEV, 'help string') as PollEvLf;
  components TagPacketC;

  TagVx.super = Root;
  TagVx.TagPacket -> TagPacketC.TagPacket;

  PollVx.Super <- TagVx.Sub[unique(UQ_TN_NAME_TAG)];
  PollVx.TagPacket -> TagPacketC.TagPacket;

  PollNidVx.Super <- TagVx.Sub[unique(UQ_TN_NAME_POLL)];
  PollNidVx.TagPacket -> TagPacketC.TagPacket;

  PollEvLf.Super <- TagVx.Sub[unique(UQ_TN_NAME_POLLNID)];
  PollEvLf.TagPacket -> TagPacketC.TagPacket;
}
