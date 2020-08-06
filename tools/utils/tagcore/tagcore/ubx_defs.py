# Copyright (c) 2020 Eric B. Decker
# All rights reserved.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
# See COPYING in the top level directory of this source tree.
#
# Contact: Eric B. Decker <cire831@gmail.com>

'''ublox binary protocol basic definitions

define manipulation and basic definitions for ubxbin protocol packets
'''

# Class/Id (cid) Table
#
# dictionary of all gps Class/Id records we understand.  Similar to
# dt_records but for gps messages.
#
# key is ubx class/id.  Contents is vector (decoder, emitter_list, obj, name).
#
# class/id decoders when imported need to populate the table.


# __all__ exports commonly used definitions.

import struct

__version__ = '0.4.8.dev2'

__all__ = [
    'CID_DECODER',
    'CID_EMITTERS',
    'CID_OBJECT',
    'CID_NAME',
    'CID_OBJ_NAME',

    'UBX_MAX_PAYLOAD',
    'UBX_SOP_SEQ',
    'UBX_HDR_SIZE',

    'UBX_CLASS_OFFSET',
    'UBX_ID_OFFSET',

    'cid_name',
]


# CID is short for Class/Id.
#
# cid_table holds vectors for how to decode a ubxbin packet.
# each entry is keyed by the CID and contains a 4-tuple that
# includes 0: decoder, 1: emitter list, 2: object string
# and 3: the name of the packet.
#
# the cid_object is a base_obj encoding of the object needed by the
# class/id.  When evaluated the tuple will display the name of the object
# rather than the __repr__ of the object (decode_base), which
# typically is some value.  What you want to see is the object name.

cid_table    = {}
cid_count    = {}

CID_DECODER  = 0
CID_EMITTERS = 1
CID_OBJECT   = 2
CID_NAME     = 3
CID_OBJ_NAME = 4

UBX_MAX_PAYLOAD  = 2048

# hdr_struct is little endian, 2 byte SOP, 1 byte Class, 1 byte Id, 2 byte len
UBX_SOP_SEQ    = 0xb562
ubx_hdr_str    = '>HH'
ubx_hdr_struct = struct.Struct(ubx_hdr_str)
UBX_HDR_SIZE   = ubx_hdr_struct.size

UBX_CLASS_OFFSET = UBX_HDR_SIZE
UBX_ID_OFFSET    = UBX_CLASS_OFFSET + 1

def cid_name(cid):
    v = cid_table.get(cid, (None, None, None, 'cid/' + '{:04x}'.format(cid)))
    return v[CID_NAME]
