/**
 * Copyright @ 2016 Dan Maltbie
 * @author Dan Maltbie
 */

Generic module TagNetParseNameP(tag_tlv *my_tlv,
                           char *my_name, byte *help_s) @safe() {
  provides interface {
    TagnetNameSpanner as Super[tn_id_t id];
  }
  uses interface {
    TagnetNameSpanner as Super[tn_id_t id];
    interface TagnetPacket as pkt;
  }
}
implementation {
 enum {SUB_COUNT = uniqueCount(my_name)};

 async event bool Super.traverse_name[id](tagmsg_t *msg) {
   uint8_t        x;

   if (call Pkt.match_node_id(msg)) {   // further processing if name matches
     call Pkt.match_special_tlvs(msg);                // consume special tlvs
     if (call Pkt.find_next_tlv(msg)) { // traverse sub if more name to parse
       for (x=0; x < SUB_COUNT; x++) {
	 if (signal Sub.traverse_name[x](msg)) return TRUE;
       }
     } else {                                     // else perform aggregation
       for (x=0; x < SUB_COUNT; x++) {
	 signal Sub.add_name_tlv[x](msg);
       }
       return TRUE;
     }
   }                              // otherwise, no match. set error and return
   Call Pkt.set_error(TN_PKT_NO_MATCH);
   return FALSE;
 }

 async signal void Super.add_value_tlv[id](tagmsg_t *msg) {
   TagPacket.add_tlv(msg, TLV_STRING, my_name, len(my_name));
   TagPacket.add_tlv(msg, TLV_INT, SUB_COUNT);
 }
 async signal void Super.add_name_tlv[id](tagmsg_t *msg) {
   TagPacket.add_tlv(msg, TLV_STRING, my_name, len(my_name));
 }
 async command void Super.add_help_tlv[id](tagmsg_t *msg) {
   TagPacket.add_tlv(msg, TLV_STRING, help_s, len(help_s));
 }
 async command Sub.get_full_name[id](byte* buf, uint8_t len) {
   uint8_t     x, offset;
   offset = call super.get_full_name(buf, len);
   for (x=0; (offset < len) && (x < len(my_tlv); offset++, x++) {
     buf[offset] = my_tlv[x];
     }
 }
}
