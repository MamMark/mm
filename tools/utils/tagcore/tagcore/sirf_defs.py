# Copyright (c) 2018-2019 Eric B. Decker
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

'''sirf binary protocol basic definitions

define manipulation and basic definitions for sirfbin/OSP protocol
packets
'''

# mid_table
#
# dictionary of all gps Message ID records we understand.  Similar
# to dt_records but for gps messages.
#
# key is gps mid.  Contents is vector (decoder, emitter_list, obj, name).
#
# mid decoders when imported need to populate the table.


# __all__ exports commonly used definitions.  It gets used
# when someone does a wild import of this module.

import struct

__version__ = '0.4.6'

__all__ = [
    'MID_DECODER',
    'MID_EMITTERS',
    'MID_OBJECT',
    'MID_NAME',
    'MID_OBJ_NAME',

    'EE_DECODER',
    'EE_EMITTERS',
    'EE_OBJECT',
    'EE_NAME',
    'EE_OBJ_NAME',

    'SIRF_MAX_PAYLOAD',
    'SIRF_SOP_SEQ',
    'SIRF_HDR_SIZE',

    'SIRF_MID_OFFSET',
    'SIRF_SID_OFFSET',

    'SIRF_EOP_SEQ',
    'SIRF_END_SIZE'
]


# mid_table holds vectors for how to decode a sirfbin packet.
# each entry is keyed by Mid and contains a 4-tuple that
# includes 0: decoder, 1: emitter list, 2: object string
# and 3: the name of the packet.
#
# the mid_object is a string encoding of the object needed by the
# mid.  When evaluated the tuple will display the name of the object
# rather than the __repr__ of the object (decode_base), which
# typically is some value.  What you want to see is the object name.

mid_table = {}
mid_count = {}

MID_DECODER  = 0
MID_EMITTERS = 1
MID_OBJECT   = 2
MID_NAME     = 3
MID_OBJ_NAME = 4


# Sid dispatch table, ee{56,232}, tcxo, etc.
#
# Each table holds vectors for how to decode extended ephemeris and tcxo
# packets, mids 56, 93, 221, and 232.  EE_ defines are used to access the
# vectors pulled from the tables.  The ee56, tcxo93, tcxo221, and ee232
# tables contain the same tuples.

ee56_table  = {}
ee56_count  = {}

nl64_table  = {}
nl64_count  = {}

stat70_table  = {}
stat70_count  = {}

stat212_table = {}
stat212_count = {}

mid225_table = {}
mid225_count = {}

ee232_table = {}
ee232_count = {}

tcxo93_table  = {}
tcxo221_table = {}

EE_DECODER  = 0
EE_EMITTERS = 1
EE_OBJECT   = 2
EE_NAME     = 3
EE_OBJ_NAME = 4


# SIRF_MAX_PAYLOAD is the maximum payload bytes we allow.
# the protocol allows for up to 2^11 - 1 (2047)

SIRF_MAX_PAYLOAD = 2047

# hdr_struct is big endian, 2 byte SOP, 2 byte len, 1 byte mid
SIRF_SOP_SEQ    = 0xa0a2
sirf_hdr_str    = '>HH'
sirf_hdr_struct = struct.Struct(sirf_hdr_str)
SIRF_HDR_SIZE   = sirf_hdr_struct.size

# SID if present is the next byte
SIRF_MID_OFFSET = SIRF_HDR_SIZE
SIRF_SID_OFFSET = SIRF_MID_OFFSET + 1

# end_struct is big endian, 2 byte chksum, 2 byte EOP
SIRF_EOP_SEQ    = 0xb0b3
sirf_end_str    = '>HH'
sirf_end_struct = struct.Struct(sirf_end_str)
SIRF_END_SIZE   = sirf_end_struct.size
