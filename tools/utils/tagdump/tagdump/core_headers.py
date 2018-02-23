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
    ('datetime',atom(('10s', '{}', binascii.hexlify))),
    ('prev',    atom(('<I', '{:08x}'))),
    ('majik',   atom(('<I', '{:08x}'))),
    ('dt_rev',  atom(('<I', '{:08x}'))),
    ('base',    atom(('<I', '{:08x}')))]))

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
    ('fault_gold',      atom(('<I', '0x{:08x}'))),
    ('fault_nib',       atom(('<I', '0x{:08x}'))),
    ('subsys_disable',  atom(('<I', '0x{:08x}'))),
    ('ow_sig_b',        atom(('<I', '0x{:08x}'))),
    ('ow_req',          atom(('<B', '{}'))),
    ('reboot_reason',   atom(('<B', '{}'))),
    ('ow_boot_mode',    atom(('<B', '{}'))),
    ('owt_action',      atom(('<B', '{}'))),
    ('reboot_count',    atom(('<I', '{}'))),
    ('elapsed',         atom(('<Q', '0x{:08x}'))),
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
    ('datetime',  atom(('10s','{}', binascii.hexlify))),
    ('prev_sync', atom(('<I', '{:x}'))),
    ('majik',     atom(('<I', '{:08x}')))]))


# EVENT
event_names = {
     1: "SURFACED",
     2: "SUBMERGED",
     3: "DOCKED",
     4: "UNDOCKED",

     5: "GPS_GEO",
     6: "GPS_XYZ",
     7: "GPS_TIME",

     8: "SSW_DELAY_TIME",
     9: "SSW_BLK_TIME",
    10: "SSW_GRP_TIME",
    11: "PANIC_WARN",

    32: "GPS_BOOT",
    33: "GPS_BOOT_TIME",
    49: "GPS_BOOT_FAIL",
    50: "GPS_HW_CONFIG",
    34: "GPS_RECONFIG",
    35: "GPS_TURN_ON",
    36: "GPS_TURN_OFF",
    37: "GPS_STANDBY",
    38: "GPS_MPM",
    39: "GPS_FULL_PWR",
    40: "GPS_PULSE",
    41: "GPS_FAST",
    42: "GPS_FIRST",
    43: "GPS_SATS_2",
    44: "GPS_SATS_7",
    45: "GPS_SATS_41",
    46: "GPS_CYCLE_TIME",
    47: "GPS_RX_ERR",
    48: "GPS_AWAKE_S",
}

PANIC_WARN = 11


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
