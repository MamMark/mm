/**
 * Copyright @ 2016 Dan Maltbie
 * @author Dan Maltbie
 */

interface TagnetNameSpanner {
  /*
  ** traverse_name - compares current name segment with module's name_tlv
  **
  */
  event bool traverse_name(tagmsg_t* msg);
  /*
  ** add_name_tlv
  **
  */
  event void add_name_tlv(tagmsg_t* msg);
  /*
  ** add_value_tlv
  **
  */
  event void add_value_tlv(tagmsg_t* msg);
  /*
  ** add_help_tlv
  **
  */
  event void add_help_tlv(tagmsg_t* msg);
  /*
  ** traverse_name - compares current name segment with module's name_tlv
  **
  */
  command void get_full_name(byte* buf, uint8_t len);
}


