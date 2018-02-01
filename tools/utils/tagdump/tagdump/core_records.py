# Copyright (c) 2018 Eric B. Decker, Daniel J. Maltbie
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
# Contact: Daniel J. Maltbie <dmaltbie@daloma.org>
#          Eric B. Decker <cire831@gmail.com>

# core record definitions.
#
# define low level record manipulation and basic definitions for record
# headers.
#

import struct
import globals as g
from   misc_utils import *

# Our definitions need to match definition in include/typed_data.h.
# The value of DT_H_REVISION reflects the version of typed_data.h that
# we have implemented.  Includes record definitions, headers and decoders.

DT_H_REVISION           = 12


# dt_records
#
# dictionary of all data_typed records we understand dict key is the
# record id (rtype).  Contents of each entry is a vector consisting of
# (req_len, decoder, object, name).
#
# req_len: required length if any.  0 if variable and not checked.
# decoder: a pointer to a routne that knows how to decode and display
#          the record
# object:  a pointer to an object descriptor for this record.
# name:    a string denoting the printable name for this record.
#
#
# when decoder code is imported, it is required to populate its entry
# in the dt_records dictionary.  Each decode is required to know its
# key and uses that to insert its vector (req_len. decode, obj, name)
# into the dictionary.

DTR_REQ_LEN = 0                         # required length
DTR_DECODER = 1                         # decode said rtype
DTR_OBJ     = 2                         # rtype obj descriptor
DTR_NAME    = 3                         # rtype name

# dt_records describes what records we understand.  It lives in globals.py
# and gets populated by the decoders.
#
# dt_count keeps track of what rtypes we have seen.
#
# dt_records = {}
# dt_count   = {}


# mid_table
#
# dictionary of all gps Message ID records we understand.  Similar
# to dt_records but for gps messages.
#
# key is gps mid.  Contents is vector (decoder, obj, name).
#
# mid decoders when imported need to populate the table.  MID ids are
# defined in gps_decoders.

MID_DECODER = 0
MID_OBJECT  = 1
MID_NAME    = 2

# mid_table is the dictionary describing all the gps MIDs we understand.
# it gets populated by gps decoders.  Lives in globals.py.
#
# mid_table = {}
# mid_count = {}


# all dt parts are native and little endian

# hdr object dt, native, little endian
# do not include the pad bytes.  Each hdr definition handles
# the pad bytes differently.

dt_hdr_str    = '<HHIQH'
dt_hdr_struct = struct.Struct(dt_hdr_str)
dt_hdr_size   = dt_hdr_struct.size
dt_sync_majik = 0xdedf00ef
quad_struct   = struct.Struct('<I')      # for searching for syncs

DT_REBOOT               = 1
DT_VERSION              = 2
DT_SYNC                 = 3
DT_EVENT                = 4
DT_DEBUG                = 5
DT_GPS_VERSION          = 16
DT_GPS_TIME             = 17
DT_GPS_GEO              = 18
DT_GPS_XYZ              = 19
DT_SENSOR_DATA          = 20
DT_SENSOR_SET           = 21
DT_TEST                 = 22
DT_NOTE                 = 23
DT_CONFIG		= 24
DT_GPS_RAW_SIRFBIN      = 32


def dt_name(rtype):
    v = g.dt_records.get(rtype, (0, None, None, 'unk'))
    return v[DTR_NAME]


def print_hdr(obj):
    # rec  time     rtype name
    #    1 00000279 (20) REBOOT

    rtype  = obj['hdr']['type'].val
    recnum = obj['hdr']['recnum'].val
    st     = obj['hdr']['st'].val

    # gratuitous space shows up after the print, sigh
    print('{:4} {:8} ({:2}) {:6} --'.format(recnum, st,
        rtype, dt_name(rtype))),



# used for identifing records that have problems.
# offset recnum systime len type name         offset
# 999999 999999 0009999 999   99 xxxxxxxxxxxx @999999 (0xffffff) [0xffff]
rec_title_str = "--- offset  recnum  systime  len  type  name"
rec_format    = "{:8} {:6}  {:7}  {:3}    {:2}  {:12s} @{} (0x{:06x}) [0x{:04x}]"

def print_record(offset, buf):
    if (len(buf) < dt_hdr_size):
        print('*** print_record, buf too small for a header, wanted {}, got {}, @{}'.format(
            dt_hdr_size, len(buf), offset))
        dump_buf(buf, '    ')
    else:
        rlen, rtype, recnum, systime, recsum = dt_hdr_struct.unpack_from(buf)
        print(rec_format.format(offset, recnum, systime, rlen, rtype,
            dt_name(rtype), offset, offset, recsum))
