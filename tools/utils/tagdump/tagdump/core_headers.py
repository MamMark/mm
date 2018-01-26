# Copyright (c) 2017-2018, Daniel J. Maltbie, Eric B. Decker
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

# basic data type object descriptors

import binascii
from   decode_base  import *
from   collections  import OrderedDict

dt_hdr_obj = aggie(OrderedDict([
    ('len',     atom(('<H', '{}'))),
    ('type',    atom(('<H', '{}'))),
    ('recnum',  atom(('<I', '{}'))),
    ('st',      atom(('<Q', '0x{:x}'))),
    ('recsum',  atom(('<H', '0x{:04x}')))]))

datetime_obj = aggie(OrderedDict([
    ('jiffies', atom(('<H', '{}'))),
    ('sec',     atom(('<B', '{}'))),
    ('min',     atom(('<B', '{}'))),
    ('hr',      atom(('<B', '{}'))),
    ('dow',     atom(('<B', '{}'))),
    ('day',     atom(('<B', '{}'))),
    ('mon',     atom(('<B', '{}'))),
    ('yr',      atom(('<H', '{}')))]))

dt64_obj = aggie(OrderedDict([
    ('jiffies', atom(('<H', '{}'))),
    ('sec',     atom(('<B', '{}'))),
    ('min',     atom(('<B', '{}'))),
    ('hr',      atom(('<B', '{}'))),
    ('dow',     atom(('<B', '{}'))),
    ('day',     atom(('<B', '{}'))),
    ('mon',     atom(('<B', '{}')))]))

dt_simple_hdr   = aggie(OrderedDict([('hdr', dt_hdr_obj)]))

dt_reboot_obj   = aggie(OrderedDict([
    ('hdr',     dt_hdr_obj),
    ('pad0',    atom(('<H', '{:04x}'))),
    ('majik',   atom(('<I', '{:08x}'))),
    ('prev',    atom(('<I', '{:08x}'))),
    ('dt_rev',  atom(('<I', '{:08x}'))),
    ('base',    atom(('<I', '{:08x}'))),
    ('datetime',atom(('10s', '{}', binascii.hexlify))),
    ('pad1',    atom(('<H',  '{}')))]))

#
# reboot is followed by the ow_control_block
# We want to decode that as well.  native order, little endian.
# see OverWatch/overwatch.h.
#
owcb_obj        = aggie(OrderedDict([
    ('ow_sig',          atom(('<I', '0x{:08x}'))),
    ('rpt',             atom(('<I', '0x{:08x}'))),
    ('uptime',          atom(('<Q', '0x{:08x}'))),
    ('reset_status',    atom(('<I', '0x{:08x}'))),
    ('reset_others',    atom(('<I', '0x{:08x}'))),
    ('from_base',       atom(('<I', '0x{:08x}'))),
    ('fail_count',      atom(('<I', '{}'))),
    ('ow_req',          atom(('<B', '{}'))),
    ('reboot_reason',   atom(('<B', '{}'))),
    ('ow_boot_mode',    atom(('<B', '{}'))),
    ('owt_action',      atom(('<B', '{}'))),
    ('ow_sig_b',        atom(('<I', '0x{:08x}'))),
    ('elapsed',         atom(('<Q', '0x{:08x}'))),
    ('reboot_count',    atom(('<I', '{}'))),
    ('strange',         atom(('<I', '{}'))),
    ('strange_loc',     atom(('<I', '0x{:04x}'))),
    ('vec_chk_fail',    atom(('<I', '{}'))),
    ('image_chk_fail',  atom(('<I', '{}'))),
    ('ow_sig_c',        atom(('<I', '0x{:08x}')))
]))


dt_version_obj  = aggie(OrderedDict([
    ('hdr',       dt_hdr_obj),
    ('pad',       atom(('<H', '{:04x}'))),
    ('base',      atom(('<I', '{:08x}')))]))


hw_version_obj      = aggie(OrderedDict([
    ('rev',       atom(('<B', '{:x}'))),
    ('model',     atom(('<B', '{:x}')))]))


image_version_obj   = aggie(OrderedDict([
    ('build',     atom(('<H', '{:x}'))),
    ('minor',     atom(('<B', '{:x}'))),
    ('major',     atom(('<B', '{:x}')))]))


image_info_obj  = aggie(OrderedDict([
    ('ii_sig',    atom(('<I', '0x{:08x}'))),
    ('im_start',  atom(('<I', '0x{:08x}'))),
    ('im_len',    atom(('<I', '0x{:08x}'))),
    ('vect_chk',  atom(('<I', '0x{:08x}'))),
    ('im_chk',    atom(('<I', '0x{:08x}'))),
    ('ver_id',    image_version_obj),
    ('desc0',     atom(('44s', '{:s}'))),
    ('desc1',     atom(('44s', '{:s}'))),
    ('build_date',atom(('30s', '{:s}'))),
    ('hw_ver',    hw_version_obj)]))


dt_sync_obj     = aggie(OrderedDict([
    ('hdr',       dt_hdr_obj),
    ('pad0',      atom(('<H', '{:04x}'))),
    ('majik',     atom(('<I', '{:08x}'))),
    ('prev_sync', atom(('<I', '{:x}'))),
    ('datetime',  atom(('10s','{}', binascii.hexlify)))]))


# EVENT

event_names = {
     1: "SURFACED",
     2: "SUBMERGED",
     3: "DOCKED",
     4: "UNDOCKED",
     5: "GPS_BOOT",
     6: "GPS_BOOT_TIME",
     7: "GPS_RECONFIG",
     8: "GPS_START",
     9: "GPS_OFF",
    10: "GPS_STANDBY",
    11: "GPS_FAST",
    12: "GPS_FIRST",
    13: "GPS_SATS_2",
    14: "GPS_SATS_7",
    15: "GPS_SATS_29",
    16: "GPS_CYCLE_TIME",
    17: "GPS_GEO",
    18: "GPS_XYZ",
    19: "GPS_TIME",
    20: "GPS_RX_ERR",
    21: "SSW_DELAY_TIME",
    22: "SSW_BLK_TIME",
    23: "SSW_GRP_TIME",
    24: "PANIC_WARN",
}

PANIC_WARN = 24


dt_event_obj    = aggie(OrderedDict([
    ('hdr',   dt_hdr_obj),
    ('event', atom(('<H', '{}'))),
    ('arg0',  atom(('<I', '0x{:04x}'))),
    ('arg1',  atom(('<I', '0x{:04x}'))),
    ('arg2',  atom(('<I', '0x{:04x}'))),
    ('arg3',  atom(('<I', '0x{:04x}'))),
    ('pcode', atom(('<B', '{}'))),
    ('w',     atom(('<B', '{}')))]))

dt_debug_obj    = dt_simple_hdr
dt_test_obj     = dt_simple_hdr
dt_note_obj     = dt_simple_hdr
dt_config_obj   = dt_simple_hdr
