'''basic definitions for sirfbin objects'''

# Copyright (c) 2018 Eric B. Decker
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

# sirf binary protocol basic definitions
#
# define manipulation and basic definitions for sirfbin/OSP protocol
# packets
#

# mid_table
#
# dictionary of all gps Message ID records we understand.  Similar
# to dt_records but for gps messages.
#
# key is gps mid.  Contents is vector (decoder, obj, name).
#
# mid decoders when imported need to populate the table.  MID ids are
# defined in gps_decoders.


# __all__ exports commonly used definitions.  It gets used
# when someone does a wild import of this module.

import struct

__version__ = '0.0.1 (sd)'

__all__ = [
    'MID_DECODER',
    'MID_OBJECT',
    'MID_NAME',
    'SIRF_MAX_PAYLOAD',
    'SIRF_SOP_SEQ',
    'SIRF_EOP_SEQ'
]

mid_table = {}
mid_count = {}

MID_DECODER = 0
MID_OBJECT  = 1
MID_NAME    = 2

# SIRF_MAX_PAYLOAD is the maximum payload bytes we allow.
# the protocol allows for up to 2^^11 - 1 (2047)

SIRF_MAX_PAYLOAD = 2047

# hdr_struct is big endian, 2 byte SOP, 2 byte len
SIRF_SOP_SEQ    = 0xa0a2
sirf_hdr_str    = '>HH'
sirf_hdr_struct = struct.Struct(sirf_hdr_str)
sirf_hdr_size   = sirf_hdr_struct.size

# end_struct is big endian, 2 byte chksum, 2 byte EOP
SIRF_EOP_SEQ    = 0xb0b3
sirf_end_str    = '>HH'
sirf_end_struct = struct.Struct(sirf_end_str)
sirf_end_size   = sirf_end_struct.size
