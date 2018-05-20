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
 * This module provides functions for handling Tagnet TLVs
 *<p>
 * A Tagnet TLV consists of three fields: (1) the one byte type field,
 * (2) a one byte length field, and (3) zero or more bytes of value.
 * The value field is interpreted based on the type field.
 *</p>
 *<p>
 * There are functions to copy, compare, and inspect TLVs as
 * well as to convert a TLV to/from a C type. See TagnetTLV.nc
 * for more details on these functions.
 *</p>
 *<p>
 * The Tagnet TLV is defined in TagnetTLV.h and consists of three fields:
 *</p>
 *<dl>
 *  <dt>type</dt> <dd>byte field defining data types, typically stored
 *  in a compressed format</dd>
 *  <dt>length</dt> <dd>byte field specifying length of the value field</dd>
 *  <dt>value</dt> <dd>field of zero or more bytes interpreted in context
 *  of type</dd>
 *</dl>
 *<p>
 * The structure definition for the Tagnet TLV is:
 *</p>
 *<code>
 * typedef struct tagnet_tlv_t {<br>
 *   tagnet_tlv_type_t typ;<br>
 *   uint8_t           len;<br>
 *   uint8_t           val[];<br>
 * } tagnet_tlv_t;<br>
 *</code>
 *<p>
 * Possible Tagnet TLV types include (see TagnetTLV.h for definitive list):
 *</p>
 *<code>
 * typedef enum {<br>
 *   TN_TLV_NONE=0,<br>
 *   TN_TLV_STRING=1,<br>
 *   TN_TLV_INTEGER=2,<br>
 *   TN_TLV_GPS_XYZ=3,<br>
 *   TN_TLV_UTC_TIME=4,<br>
 *   TN_TLV_NODE_ID=5,<br>
 *   TN_TLV_NODE_NAME=6,<br>
 *   TN_TLV_OFFSET=7,<br>
 *   TN_TLV_SIZE=8,<br>
 *   TN_TLV_EOF=9,<br>
 *   TN_TLV_VERSION=10,<br>
 *   TN_TLV_BLK=11,<br>
 *   _TN_TLV_COUNT   // limit of enum values<br>
 * } tagnet_tlv_type_t;<br>
 *</code>
 */

#include <TagnetTLV.h>
#include <rtctime.h>
#include <tagnet_panic.h>


module TagnetTlvP {
  provides interface TagnetTLV;
  uses     interface Panic;
}
implementation {

  inline void tn_panic(uint8_t where, parg_t arg0, parg_t arg1,
                               parg_t arg2, parg_t arg3) {
    call Panic.panic(PANIC_TAGNET, where, arg0, arg1, arg2, arg3);
  }


  uint32_t _copy_bytes(uint8_t *s, uint8_t *d, uint32_t l) {
    uint32_t x = l;

    while (x) {
      *d++ = *s++;
      x--;
    }
    return l;
  }


  bool  _cmp_bytes(uint8_t *s, uint8_t *d, uint32_t l) {
    while (l) {
      if (*d++ != *s++) return FALSE;
      l--;
    }
    return TRUE;
  }


  uint32_t str2tlv(tagnet_tlv_type_t ttype, uint8_t *s, uint32_t length, tagnet_tlv_t *t, uint32_t limit) {
    if ((t) && ((length + sizeof(tagnet_tlv_t)) < limit)) {
      _copy_bytes(s, (uint8_t *)&t->val[0], length);
      t->len = length;
      t->typ = ttype;
      return SIZEOF_TLV(t);
    }
    return 0;
  }


  uint8_t *tlv2str(tagnet_tlv_type_t ttype, tagnet_tlv_t *t, uint32_t *len) {
    if ((t) && (t->typ == ttype)) {
      uint8_t  *s = (uint8_t *) &t->val;
      *len = t->len;
      return s;
    }
    return NULL;
  }

  uint32_t int2tlv(tagnet_tlv_type_t ttype, int32_t i, tagnet_tlv_t *t, uint32_t limit) {
    int32_t    c = 0;
    bool       first = TRUE;
    int32_t    x;
    uint8_t    v;
    if ((t) && ((sizeof(int32_t) + sizeof(tagnet_tlv_t)) < limit)) {
      for (x = sizeof(int)-1; x >= 0; x--) {
        v = (uint8_t) (i >> (x*8));
        if (v || !first) {
          t->val[c++] = v;
          first = FALSE;
        }
      }
      if (c == 0) t->val[c++] = 0;
      t->len = c;
      t->typ = ttype;
      if (t->typ < _TN_TLV_COUNT)
        return SIZEOF_TLV(t);
    }
    return 0;
  }

    int32_t tlv2int(tagnet_tlv_type_t ttype, tagnet_tlv_t *t) {
    uint8_t        x;
    int32_t        v = 0;

    if (!t || t->typ != ttype || t->len > sizeof(uint32_t))
      tn_panic(TAGNET_AUTOWHERE, (parg_t) t, t->typ, t->len, ttype);
    if ((t) && (t->typ == ttype) && (t->len <= 4)) {
      for (x = 0; x < t->len; x++) {
        v = t->val[x] + (v << 8);
      }
    }
    return v;
  }


  command uint32_t   TagnetTLV.block_to_tlv(uint8_t *s, uint32_t length,
                                                    tagnet_tlv_t *t, uint32_t limit) {
    return str2tlv(TN_TLV_BLK, s, length, t, limit);
  }

  command uint32_t   TagnetTLV.copy_tlv(tagnet_tlv_t *s,  tagnet_tlv_t *d, uint32_t limit) {
    uint32_t l = SIZEOF_TLV(s);

    if (l > limit)
      tn_panic(TAGNET_AUTOWHERE, l, limit, 0, 0);
    return _copy_bytes((uint8_t *) s, (uint8_t *) d, l);
  }


  command bool   TagnetTLV.eq_tlv(tagnet_tlv_t *s, tagnet_tlv_t *t) {
    if ((s->typ >= _TN_TLV_COUNT) || (t->typ >= _TN_TLV_COUNT))
      tn_panic(TAGNET_AUTOWHERE, (parg_t) s, s->typ, (parg_t) t, t->typ);
    nop();                              /* BRK */
    return (_cmp_bytes((uint8_t *)s, (uint8_t *)t, SIZEOF_TLV(s)));
  }


  command uint32_t   TagnetTLV.get_len(tagnet_tlv_t *t) {
    if (t->typ >= _TN_TLV_COUNT)
      tn_panic(TAGNET_AUTOWHERE, (parg_t) t, t->typ, t->len, 0);
    return SIZEOF_TLV(t);
  }

  command uint32_t   TagnetTLV.get_len_v(tagnet_tlv_t *t) {
    if (t->typ >= _TN_TLV_COUNT)
      tn_panic(TAGNET_AUTOWHERE, (parg_t) t, t->typ, t->len, 0);
    return t->len;
  }

  command
//    __attribute__((optimize("O0")))
    tagnet_tlv_t  *TagnetTLV.get_next_tlv(tagnet_tlv_t *t, uint32_t limit) {
    tagnet_tlv_t  *next_tlv;
    uint32_t        nx;

    if (t->len == 0 || t->typ == TN_TLV_NONE)
      return NULL;
    if (t->typ >= _TN_TLV_COUNT)
      tn_panic(TAGNET_AUTOWHERE, (parg_t) t, t->typ, t->len, 0);

    nx = SIZEOF_TLV(t);
    if (nx < limit) {
      next_tlv = (void *) ((uintptr_t) t + nx);
      if ((next_tlv->len > 0)                &&
          (next_tlv->len <= (limit - nx))    &&
          (next_tlv->typ != TN_TLV_NONE)     &&
          (next_tlv->typ < _TN_TLV_COUNT)) {
        return next_tlv;
      }
    }
    return NULL;
  }


  command tagnet_tlv_type_t TagnetTLV.get_tlv_type(tagnet_tlv_t *t) {
    if (t->typ >= _TN_TLV_COUNT)
      tn_panic(TAGNET_AUTOWHERE, (parg_t) t, t->typ, t->len, 0);
    return t->typ;
  }


  command uint32_t  TagnetTLV.gps_xyz_to_tlv(tagnet_gps_xyz_t *xyz,  tagnet_tlv_t *t, uint32_t limit) {
    int32_t    x;
    uint8_t   *v = (void *) xyz;

    nop();                              /* BRK */
    if ((t) && ((sizeof(tagnet_gps_xyz_t) + sizeof(tagnet_tlv_t)) < limit)) {
      t->typ = TN_TLV_GPS_XYZ;
      t->len = TN_GPS_XYZ_LEN;
      for (x = 0; x < TN_GPS_XYZ_LEN; x++) {
        if (x >= limit) break;
        t->val[x] = v[x];
      }
      return (x == TN_GPS_XYZ_LEN) ? SIZEOF_TLV(t) : 0;
    }
    return 0;
  }

  command uint32_t  TagnetTLV.delay_to_tlv(int32_t i,  tagnet_tlv_t *t, uint32_t limit) {
    return int2tlv(TN_TLV_DELAY, i, t, limit);
  }


  command uint32_t   TagnetTLV.rtctime_to_tlv(rtctime_t *v, tagnet_tlv_t *t, uint32_t limit) {
    uint32_t        i;
    uint8_t        *vb;

    if ((!t) || ((sizeof(rtctime_t) + sizeof(tagnet_tlv_t)) > limit))
      tn_panic(TAGNET_AUTOWHERE, (parg_t) t, t->typ, t->len, limit);
    vb = (uint8_t *) v;
    for (i = 0; i < sizeof(*v); i++)
      t->val[i] = vb[i];
    t->typ = TN_TLV_UTC_TIME;
    t->len = sizeof(rtctime_t);
    return SIZEOF_TLV(t);
  }


  command uint32_t  TagnetTLV.error_to_tlv(int32_t err,  tagnet_tlv_t *t, uint32_t limit) {
    return int2tlv(TN_TLV_ERROR, err, t, limit);
  }


  command uint32_t  TagnetTLV.integer_to_tlv(int32_t i,  tagnet_tlv_t *t, uint32_t limit) {
    return int2tlv(TN_TLV_INTEGER, i, t, limit);
  }


  command uint32_t  TagnetTLV.offset_to_tlv(int32_t i, tagnet_tlv_t *t, uint32_t limit) {
    return int2tlv(TN_TLV_OFFSET, i, t, limit);
  }

  command uint32_t  TagnetTLV.size_to_tlv(int32_t i, tagnet_tlv_t *t, uint32_t limit) {
    return int2tlv(TN_TLV_SIZE, i, t, limit);
  }

  command bool   TagnetTLV.is_special_tlv(tagnet_tlv_t *t) {
    switch (t->typ) {
      case TN_TLV_VERSION:
      case TN_TLV_SIZE:
      case TN_TLV_OFFSET:
      case TN_TLV_NODE_ID:
      case TN_TLV_NODE_NAME:
      case TN_TLV_GPS_XYZ:
      case TN_TLV_UTC_TIME:
      case TN_TLV_RECNUM:
      case TN_TLV_RECCNT:
      case TN_TLV_ERROR:
        return TRUE;
      default:
        return FALSE;
    }
    return FALSE; // shouldn't get here
  }


  command int   TagnetTLV.repr_tlv(tagnet_tlv_t *t,  uint8_t *b, uint32_t limit) {
    switch (t->typ) {
      case TN_TLV_STRING:
        if (t->len > limit) return -1;
        return _copy_bytes((uint8_t *)&t->val[0], b,  t->len);
      default:
        return -1;
    }
    return -1;   // shouldn't get here
  }

  command uint32_t   TagnetTLV.string_to_tlv(uint8_t *s, uint32_t length,
                                                    tagnet_tlv_t *t, uint32_t limit) {
    return str2tlv(TN_TLV_STRING, s, length, t, limit);
  }

  command uint8_t   *TagnetTLV.tlv_to_block(tagnet_tlv_t *t, uint32_t *len) {
    return tlv2str(TN_TLV_BLK, t, len);
  }

  command int32_t   TagnetTLV.tlv_to_delay(tagnet_tlv_t *t) {
    return tlv2int(TN_TLV_DELAY, t);
  }

  command rtctime_t   *TagnetTLV.tlv_to_rtctime(tagnet_tlv_t *t) {
    if ((t) && (t->typ == TN_TLV_UTC_TIME)) {
      return (rtctime_t *) &t->val;
    }
    return NULL;
  }

  command uint8_t   *TagnetTLV.tlv_to_node_id(tagnet_tlv_t *t) {
    if ((t) && (t->typ == TN_TLV_NODE_ID)) {
      return (uint8_t *) &t->val;
    }
    return NULL;
  }

  command uint8_t   *TagnetTLV.tlv_to_node_name(tagnet_tlv_t *t) {
    if ((t) && (t->typ == TN_TLV_NODE_NAME)) {
      return (uint8_t *) &t->val;
    }
    return NULL;
  }

  command int32_t   TagnetTLV.tlv_to_error(tagnet_tlv_t *t) {
    return tlv2int(TN_TLV_ERROR, t);
  }

  command int32_t   TagnetTLV.tlv_to_integer(tagnet_tlv_t *t) {
    return tlv2int(TN_TLV_INTEGER, t);
  }

  command int32_t   TagnetTLV.tlv_to_offset(tagnet_tlv_t *t) {
    return tlv2int(TN_TLV_OFFSET, t);
  }

  command int32_t   TagnetTLV.tlv_to_size(tagnet_tlv_t *t) {
    return tlv2int(TN_TLV_SIZE, t);
  }

  command uint8_t   *TagnetTLV.tlv_to_string(tagnet_tlv_t *t, uint32_t *len) {
    return tlv2str(TN_TLV_STRING, t, len);
  }

  command image_ver_t   *TagnetTLV.tlv_to_version(tagnet_tlv_t *t) {
    if ((t) && (t->typ == TN_TLV_VERSION)) {
      return (image_ver_t *) &t->val;
    }
    return NULL;
  }

  command uint32_t   TagnetTLV.version_to_tlv(image_ver_t *v, tagnet_tlv_t *t, uint32_t limit) {
    uint8_t         i;
    uint8_t        *vb = (uint8_t *) v;

    if ((!t) || ((sizeof(image_ver_t) + sizeof(tagnet_tlv_t)) > limit))
      tn_panic(TAGNET_AUTOWHERE, (parg_t) t, t->typ, t->len, limit);
    for (i = 0; i <  sizeof(image_ver_t); i++) {
      t->val[i]= vb[i];
    }
    t->typ = TN_TLV_VERSION;
    t->len = sizeof(image_ver_t);
    return SIZEOF_TLV(t);
  }

  async event void Panic.hook() { }
}
