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
 * This module handles Byte access to the Dblk storage files
 */

#include <TinyError.h>
#include <message.h>
#include <Tagnet.h>
#include <TagnetAdapter.h>

module Si446xMonitorP {
  provides {
           interface TagnetAdapter<message_t>  as  RadioRSSI;
           interface TagnetAdapter<message_t>  as  RadioTxPower;
  } uses {
           interface PacketField<uint8_t>      as  PacketRSSI;
           interface PacketField<uint8_t>      as  PacketTransmitPower;
           interface TagnetPayload             as  TPload;
           interface TagnetHeader              as  THdr;
           interface TagnetTLV                 as  TTLV;
  }
}
implementation {
  uint8_t    tx_power;


  /*
   * RadioRSSI.get_value
   *
   * returns the RSSI value measured for the msg just received, which
   * is carried in the msg metadata. This value is returned in the
   * payload of the response msg.
   */
  command bool RadioRSSI.get_value(message_t *msg, uint32_t *lenp) {
    switch (call THdr.get_message_type(msg)) {    // process packet type
      case TN_GET:
        call THdr.set_response(msg);
        call THdr.set_error(msg, TE_PKT_OK);
        call TPload.reset_payload(msg);
        call TPload.add_integer(msg, call PacketRSSI.get(msg));
        return TRUE;
      case  TN_HEAD:
        call THdr.set_response(msg);
        call THdr.set_error(msg, TE_PKT_OK);
        call TPload.reset_payload(msg);
        call TPload.add_offset(msg, tx_power);
        call TPload.add_size(msg, tx_power);
        return TRUE;
      default:
        break;
    }
    call THdr.set_error(msg, TE_PKT_NO_MATCH);
    return FALSE;                                  // no match, do nothing
  }


  /*
   * RadioRSSI.set_value
   *
   * There is no way to set the RSSI. (use to set the threshold?)
   */
  command bool RadioRSSI.set_value(message_t *msg, uint32_t *lenp) {
    call THdr.set_error(msg, TE_PKT_NO_MATCH);
    return FALSE;
  }


  /*
   * RadioTxPower.get_value
   *
   * return the saved value for tx_power (set in the set_value routine)
   */
  command bool RadioTxPower.get_value(message_t *msg, uint32_t *lenp) {
    switch (call THdr.get_message_type(msg)) {    // process packet type
      case TN_GET:
        call THdr.set_response(msg);
        call THdr.set_error(msg, TE_PKT_OK);
        call TPload.reset_payload(msg);
        call TPload.add_integer(msg, tx_power);
        return TRUE;
      case  TN_HEAD:
        call THdr.set_response(msg);
        call THdr.set_error(msg, TE_PKT_OK);
        call TPload.reset_payload(msg);
        call TPload.add_offset(msg, tx_power);
        call TPload.add_size(msg, tx_power);
        return TRUE;
      default:
        break;
    }
    call THdr.set_error(msg, TE_PKT_NO_MATCH);
    return FALSE;                                  // no match, do nothing
  }


  /*
   * RadioTxPower.set_value
   *
   * Sets the radio transmit power level. This is done by using the
   * message metadata of the response message to communicate with the
   * Si446x driver for indicating a new power level for the radio. The
   * radio will only update the power setting when explicitly requested.
   */
  command bool RadioTxPower.set_value(message_t *msg, uint32_t *lenp) {
    tagnet_tlv_t    *a_tlv;
    uint8_t         *a_block;
    uint32_t         ln;
    error_t          err = SUCCESS;

    switch (call THdr.get_message_type(msg)) {    // process packet type
      case TN_PUT:
        call THdr.set_response(msg);
        call THdr.set_error(msg, TE_PKT_OK);
        a_tlv = call TPload.first_element(msg);
        if (a_tlv) {
          if (call TTLV.get_tlv_type(a_tlv) == TN_TLV_INTEGER) {
            tx_power = call TTLV.tlv_to_integer(a_tlv);
            call PacketTransmitPower.set(msg, tx_power);
          } else if (call TTLV.get_tlv_type(a_tlv) == TN_TLV_BLK) {
            a_block = call TTLV.tlv_to_block(a_tlv, &ln);
            if (ln) {
              tx_power = a_block[0];
              call PacketTransmitPower.set(msg, tx_power);
            }
          } else
            err = EINVAL;
        } else
          err = EINVAL;
        call TPload.reset_payload(msg);
        if (err)
          call TPload.add_error(msg, err);
        return TRUE;
        break;
      default:
        break;
    }
    call THdr.set_error(msg, TE_PKT_NO_MATCH);
    return FALSE;                                  // no match, do nothing
  }

}
