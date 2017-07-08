/**
 * Copyright @ 2016 Dan Maltbie
 * @author Dan Maltbie
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