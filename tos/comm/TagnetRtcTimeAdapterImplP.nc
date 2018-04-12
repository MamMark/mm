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

#include <TagnetTLV.h>
#include <rtctime.h>

generic module TagnetRtcTimeAdapterImplP (int my_id) @safe() {
  uses interface  TagnetMessage             as  Super;
  uses interface  TagnetAdapter<rtctime_t>  as  Adapter;
  uses interface  TagnetName                as  TName;
  uses interface  TagnetHeader              as  THdr;
  uses interface  TagnetPayload             as  TPload;
  uses interface  TagnetTLV                 as  TTLV;
  uses interface  Rtc;
}
implementation {
  enum { my_adapter_id = unique(UQ_TAGNET_ADAPTER_LIST) };

  event bool Super.evaluate(message_t *msg) {
    tagnet_tlv_t    *name_tlv = (tagnet_tlv_t *)tn_name_data_descriptors[my_id].name_tlv;
    tagnet_tlv_t    *this_tlv = call TName.this_element(msg);
    rtctime_t        mytime;
    uint8_t         *mbp;
    uint32_t         len      = sizeof(mytime);
    tagnet_tlv_t    *nettime_tlv;
    rtctime_t       *nettime;
    uint8_t         *nbp;
    uint8_t          i;

    if (call TTLV.eq_tlv(name_tlv, this_tlv)) {
      tn_trace_rec(my_id, 1);
      call THdr.set_response(msg);
      call THdr.set_error(msg, TE_PKT_OK);
      switch (call THdr.get_message_type(msg)) {      // process message type

        case TN_HEAD:
        case TN_GET:
          tn_trace_rec(my_id, 2);
          call TPload.reset_payload(msg);
          if (call Adapter.get_value(&mytime, &len)) {
            call TPload.add_rtctime(msg, &mytime);
          } else {
            call TPload.add_error(msg, EINVAL);
          }
          return TRUE;

        case TN_PUT:
          tn_trace_rec(my_id, 3);
          nettime_tlv = call TPload.first_element(msg);
          if (call TTLV.get_tlv_type(nettime_tlv) != TN_TLV_UTC_TIME)
            break;                                    // error
          nettime = call TTLV.tlv_to_rtctime(nettime_tlv);

          /* WARNING: nettime, a pointer to rtctime_t is from a network
           * packet and not guaranteed to be properly aligned for native
           * access of the rtctime_t data.  Before access we need to
           * align the data (mbp).
           */
          call TPload.reset_payload(msg);
          len = sizeof(*nettime);
          mbp = (uint8_t *) &mytime;   // copy from msg to local struct
          nbp = (uint8_t *) nettime;   // to ensure proper word alignment
          for (i = 0; i < len; i++)
            mbp[i] = nbp[i];
          if (call Adapter.set_value(&mytime, &len)) {
            call TPload.add_error(msg, SUCCESS);
          } else {
            call TPload.add_error(msg, EINVAL);
          }
          return TRUE;

        default:
          break;
      }
    }
    call THdr.set_error(msg, TE_PKT_NO_MATCH);
    tn_trace_rec(my_id, 255);
    return FALSE;
  }

  event void Super.add_name_tlv(message_t* msg) {
    tagnet_tlv_t    *name_tlv = (tagnet_tlv_t *)tn_name_data_descriptors[my_id].name_tlv;

    call TPload.add_tlv(msg, name_tlv);
  }

  event void Super.add_value_tlv(message_t* msg) {
    rtctime_t                v;
    uint32_t                 ln = sizeof(v);

    if (call Adapter.get_value(&v, &ln) && (ln >= sizeof(v))) {
      call TPload.add_rtctime(msg, &v);
    }
  }

  event void Super.add_help_tlv(message_t* msg) {
    tagnet_tlv_t    *help_tlv = (tagnet_tlv_t *)tn_name_data_descriptors[my_id].help_tlv;
    call TPload.add_tlv(msg, help_tlv);
  }
  async event void Rtc.currentTime(rtctime_t *timep,
                                     uint32_t reason_set) { }
}
